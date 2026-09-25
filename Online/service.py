"""Amiin accounts and host-authoritative relay. Run ONE worker per service.

Persistent state uses SQLite locally or PostgreSQL on Supabase. Worlds remain
on the host's computer. No credentials or world packets are written to logs.
"""
import asyncio
import base64
import hashlib
import json
import os
import re
import secrets
import struct
import time
import threading
from collections import defaultdict, deque
from pathlib import Path

from argon2 import PasswordHasher
from argon2.exceptions import VerificationError
from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, event, text
from sqlalchemy.exc import IntegrityError
from starlette.concurrency import run_in_threadpool

DB_URL = os.environ.get("DATABASE_URL", "sqlite:///amiin.db")
IS_POSTGRES = DB_URL.startswith(("postgres://", "postgresql://"))
if IS_POSTGRES:
    DB_URL = "postgresql+psycopg://" + DB_URL.split("://", 1)[1]
db = create_engine(DB_URL, pool_pre_ping=True)
if IS_POSTGRES:
    # Keeps this service's tables in their own schema, separate from any other
    # app (e.g. the studio website) sharing the same Postgres project.
    @event.listens_for(db, "connect")
    def _set_search_path(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("SET search_path TO game, public")
        cursor.close()
with db.begin() as c:
    for sql in (["CREATE SCHEMA IF NOT EXISTS game"] if IS_POSTGRES else []) + [
        "CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, name TEXT UNIQUE NOT NULL, password TEXT NOT NULL, recovery TEXT NOT NULL)",
        "CREATE TABLE IF NOT EXISTS sessions (hash TEXT PRIMARY KEY, account TEXT NOT NULL, expires BIGINT NOT NULL, scope TEXT NOT NULL)",
        "CREATE TABLE IF NOT EXISTS grants (account TEXT NOT NULL, channel TEXT NOT NULL, PRIMARY KEY(account,channel))",
        "CREATE TABLE IF NOT EXISTS releases (channel TEXT PRIMARY KEY, envelope TEXT NOT NULL, game_version TEXT NOT NULL, protocol INTEGER NOT NULL)",
    ]:
        c.execute(text(sql))

app = FastAPI(title="Amiin Studio Online", docs_url=None, redoc_url=None)
passwords = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=2)
password_slots = threading.BoundedSemaphore(2)
dummy_password = passwords.hash(secrets.token_urlsafe(32))
limits = defaultdict(deque)
rooms = {}
tickets = {}
DEV = os.environ.get("AMIIN_DEV") == "1"


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def query(sql, **values):
    with db.begin() as c:
        result = c.execute(text(sql), values)
        return [dict(row) for row in result.mappings()] if result.returns_rows else []


def throttle(key, count, window=60):
    now = time.monotonic()
    if key not in limits and len(limits) >= 10000:
        for old in list(limits):
            if not limits[old] or limits[old][-1] < now - 3600:
                del limits[old]
        if len(limits) >= 10000:
            raise HTTPException(503, "Service busy. Try again shortly.")
    q = limits[key]
    while q and q[0] < now - window:
        q.popleft()
    if len(q) >= count:
        raise HTTPException(429, "Too many attempts. Wait a minute and try again.")
    q.append(now)
    # Bound the map when a public service receives many distinct addresses.
    if len(limits) > 10000:
        for old in list(limits):
            if not limits[old] or limits[old][-1] < now - 3600:
                del limits[old]


@app.middleware("http")
async def guard(request: Request, call_next):
    if request.method == "POST" and "content-length" not in request.headers:
        return HTMLResponse("Content-Length required", status_code=411)
    length = request.headers.get("content-length", "0")
    if not length.isdigit() or int(length) > 32768:
        return HTMLResponse("Request too large", status_code=413)
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


class Credentials(BaseModel):
    username: str = Field(min_length=3, max_length=24, pattern=r"^[A-Za-z0-9_]+$")
    password: str = Field(min_length=12, max_length=128)


def hash_password(value):
    with password_slots:
        return passwords.hash(value)


def new_session(account, scope="launcher", lifetime=86400):
    token = secrets.token_urlsafe(32)
    query("DELETE FROM sessions WHERE expires < :now", now=int(time.time()))
    query("INSERT INTO sessions VALUES (:hash,:account,:expires,:scope)",
          hash=digest(token), account=account, expires=int(time.time()) + lifetime, scope=scope)
    return token


def identity(request, scopes=("launcher", "game")):
    bearer = request.headers.get("authorization", "")
    if not bearer.startswith("Bearer "):
        raise HTTPException(401, "Sign in to Amiin Studio.")
    rows = query("SELECT a.id,a.name,s.scope FROM accounts a JOIN sessions s ON s.account=a.id WHERE s.hash=:hash AND s.expires>:now",
                 hash=digest(bearer[7:]), now=int(time.time()))
    if not rows or rows[0]["scope"] not in scopes:
        raise HTTPException(401, "Your session expired. Sign in again.")
    return rows[0]


def channels(account):
    return ["public"] + [r["channel"] for r in query("SELECT channel FROM grants WHERE account=:a", a=account)]


def allow_channel(account, channel):
    if channel not in channels(account):
        raise HTTPException(403, "This account has not been invited to this test channel.")


@app.post("/auth/register")
def register(data: Credentials, request: Request):
    throttle((request.client.host, "register"), 4, 3600)
    recovery = secrets.token_urlsafe(24)
    aid = secrets.token_hex(16)
    try:
        query("INSERT INTO accounts VALUES (:id,:name,:password,:recovery)", id=aid,
              name=data.username.lower(), password=hash_password(data.password), recovery=digest(recovery))
    except IntegrityError:
        raise HTTPException(409, "That explorer name is unavailable.")
    return {"token": new_session(aid), "recovery_code": recovery, "username": data.username.lower()}


@app.post("/auth/login")
def login(data: Credentials, request: Request):
    throttle((request.client.host, "login"), 12)
    throttle((data.username.lower(), "login-name"), 12)
    rows = query("SELECT * FROM accounts WHERE name=:name", name=data.username.lower())
    try:
        with password_slots:
            passwords.verify(rows[0]["password"] if rows else dummy_password, data.password)
    except VerificationError:
        raise HTTPException(401, "Name or password is incorrect.")
    if not rows:
        raise HTTPException(401, "Name or password is incorrect.")
    return {"token": new_session(rows[0]["id"]), "username": rows[0]["name"]}


class Recovery(Credentials):
    recovery_code: str = Field(min_length=20, max_length=100)


@app.post("/auth/recover")
def recover(data: Recovery, request: Request):
    throttle((request.client.host, "recover"), 5)
    rows = query("SELECT * FROM accounts WHERE name=:n", n=data.username.lower())
    if not rows or not secrets.compare_digest(rows[0]["recovery"], digest(data.recovery_code)):
        raise HTTPException(401, "Recovery details are incorrect.")
    code = secrets.token_urlsafe(24)
    with db.begin() as c:
        c.execute(text("UPDATE accounts SET password=:p,recovery=:r WHERE id=:id"),
                  dict(p=hash_password(data.password), r=digest(code), id=rows[0]["id"]))
        c.execute(text("DELETE FROM sessions WHERE account=:a"), dict(a=rows[0]["id"]))
    return {"recovery_code": code}


@app.post("/auth/logout")
def logout(request: Request):
    identity(request)
    query("DELETE FROM sessions WHERE hash=:h", h=digest(request.headers["authorization"][7:]))
    return {"ok": True}


@app.get("/auth/me")
def me(request: Request):
    user = identity(request)
    return {"id": user["id"], "username": user["name"], "channels": channels(user["id"])}


@app.post("/auth/launch-ticket")
def launch_ticket(request: Request):
    user = identity(request, ("launcher",))
    # A large Godot Mono game can take well over a minute to boot on first run (JIT,
    # shader compilation, asset loading), so a short-lived ticket expired before the
    # game ever got to redeem it via /auth/exchange -- surfacing as "Start the game
    # from the launcher again" even on a completely successful launch.
    return {"ticket": new_session(user["id"], "launch", 600)}


@app.post("/auth/exchange")
def exchange(request: Request):
    # DELETE RETURNING is atomic: two requests cannot redeem the same ticket.
    token = request.headers.get("authorization", "")[7:]
    rows = query("DELETE FROM sessions WHERE hash=:h AND scope='launch' AND expires>:now RETURNING account",
                 h=digest(token), now=int(time.time()))
    if not rows:
        raise HTTPException(401, "Start the game from the launcher again.")
    return {"token": new_session(rows[0]["account"], "game", 43200)}


@app.get("/releases/{channel}")
def release(channel: str, request: Request):
    user = identity(request)
    allow_channel(user["id"], channel)
    rows = query("SELECT envelope FROM releases WHERE channel=:c", c=channel)
    if not rows:
        raise HTTPException(404, "No build has been published to this channel yet.")
    return json.loads(rows[0]["envelope"])


class Build(BaseModel):
    channel: str = Field(default="public", pattern=r"^[a-z0-9-]{1,32}$")
    game_id: str = Field(default="verdant-wilds", pattern=r"^[a-z0-9-]{1,32}$")
    version: str = Field(max_length=64)
    protocol: int = 1


def find_game(manifest, game_id):
    return next((g for g in manifest.get("games", []) if g["id"] == game_id), None)


def check_build(user, build):
    allow_channel(user["id"], build.channel)
    if DEV and build.version == "dev":
        return
    rows = query("SELECT envelope FROM releases WHERE channel=:c", c=build.channel)
    manifest = json.loads(base64.b64decode(json.loads(rows[0]["envelope"])["payload"])) if rows else None
    game = find_game(manifest, build.game_id) if manifest else None
    if not game or game["package"]["version"] != build.version or game["protocol"] != build.protocol:
        raise HTTPException(409, "Update your game in the launcher before playing online.")


@app.post("/play/validate")
def validate_play(build: Build, request: Request):
    user = identity(request, ("game",))
    check_build(user, build)
    return {"id": user["id"], "username": user["name"], "channel": build.channel}


def issue_room_ticket(room, user, peer):
    now = time.monotonic()
    for key, value in list(tickets.items()):
        if value["expires"] < now:
            tickets.pop(key, None)
    token = secrets.token_urlsafe(32)
    tickets[digest(token)] = dict(room=room, user=user, peer=peer, expires=now + 90)
    return {"ticket": token, "code": room["code"], "peer_id": peer}


@app.post("/rooms")
async def host(build: Build, request: Request):
    user = await run_in_threadpool(identity, request, ("game",))
    await run_in_threadpool(check_build, user, build)
    throttle((user["id"], "room"), 6)
    now = time.monotonic()
    for code, room in list(rooms.items()):
        if not room["peers"] and room["created"] < now - 90:
            rooms.pop(code, None)
    if len(rooms) >= 100:
        raise HTTPException(503, "All relay rooms are busy. Try again shortly.")
    if any(r["host"] == user["id"] for r in rooms.values()):
        raise HTTPException(409, "Close your previous hosted world first.")
    code = "".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(8))
    while code in rooms:
        code = "".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(8))
    room = dict(code=code, host=user["id"], build=build.model_dump(), peers={}, next=2, created=now)
    rooms[code] = room
    return issue_room_ticket(room, user, 1)


@app.post("/rooms/{code}/join")
async def join(code: str, build: Build, request: Request):
    user = await run_in_threadpool(identity, request, ("game",))
    await run_in_threadpool(check_build, user, build)
    throttle((user["id"], "join"), 15)
    room = rooms.get(code.upper())
    if not room or 1 not in room["peers"]:
        raise HTTPException(404, "Invite not found. Ask your friend to host a world first.")
    if room["build"] != build.model_dump():
        raise HTTPException(409, "Host and guest must use the same channel and game version.")
    peer = room["next"]
    room["next"] += 1
    return issue_room_ticket(room, user, peer)


async def send_control(room, value, exclude=0):
    for pid, peer in list(room["peers"].items()):
        if pid != exclude:
            try:
                await peer["socket"].send_json(value)
            except (RuntimeError, WebSocketDisconnect):
                pass


@app.websocket("/relay")
async def relay(socket: WebSocket):
    auth = socket.headers.get("authorization", "")
    ticket = tickets.pop(digest(auth[7:]), None) if auth.startswith("Bearer ") else None
    if not ticket or ticket["expires"] < time.monotonic():
        await socket.close(code=1008)
        return
    room, user, pid = ticket["room"], ticket["user"], ticket["peer"]
    if rooms.get(room["code"]) is not room or len(room["peers"]) >= 6 or any(p["account_id"] == user["id"] for p in room["peers"].values()) or (pid != 1 and 1 not in room["peers"]):
        await socket.close(code=1008)
        return
    info = dict(id=pid, account_id=user["id"], username=user["name"])
    # Reserve before await so concurrent joins cannot overfill the room.
    room["peers"][pid] = dict(**info, socket=socket)
    try:
        await socket.accept()
        others = [{k: v for k, v in p.items() if k != "socket"} for p in room["peers"].values() if p["id"] != pid]
        await socket.send_json(dict(type="ready", id=pid, peers=others))
        await send_control(room, dict(type="joined", peer=info), pid)
        traffic = deque()
        while True:
            event = await asyncio.wait_for(socket.receive(), timeout=75)
            if event["type"] == "websocket.disconnect":
                break
            if event.get("text") == "ping":
                await socket.send_text('{"type":"pong"}')
                continue
            if event.get("text") and pid == 1:
                try:
                    command = json.loads(event["text"])
                    kicked = int(command.get("kick", 0))
                    if kicked > 1 and kicked in room["peers"]:
                        await room["peers"][kicked]["socket"].close(code=1008, reason="Host closed connection")
                except (ValueError, TypeError):
                    pass
                continue
            packet = event.get("bytes")
            now = time.monotonic()
            while traffic and traffic[0][0] < now - 1:
                traffic.popleft()
            if not packet or len(packet) < 8 or len(packet) > 4 * 1024 * 1024:
                await socket.close(code=1008)
                break
            traffic.append((now, len(packet)))
            if len(traffic) > 250 or sum(n for _, n in traffic) > 8 * 1024 * 1024:
                await socket.close(code=1008)
                break
            target, channel = struct.unpack_from("<ii", packet)
            if channel < 0 or channel > 7 or (pid != 1 and target != 1):
                await socket.close(code=1008)
                break
            forwarded = struct.pack("<ii", pid, channel) + packet[8:]
            for other, destination in list(room["peers"].items()):
                if other != pid and (target == 0 or target == other or (target < 0 and other != -target)):
                    await asyncio.wait_for(destination["socket"].send_bytes(forwarded), timeout=5)
    except (WebSocketDisconnect, RuntimeError, asyncio.TimeoutError):
        pass
    finally:
        room["peers"].pop(pid, None)
        if pid == 1:
            rooms.pop(room["code"], None)
            for peer in list(room["peers"].values()):
                try:
                    await peer["socket"].close(code=1001, reason="Host left the world")
                except RuntimeError:
                    pass
        else:
            await send_control(room, dict(type="left", id=pid))


@app.get("/health")
def health():
    return {"status": "ok", "protocol": 1}


@app.get("/")
def landing():
    rows = query("SELECT envelope FROM releases WHERE channel='public'")
    downloads = "<p>No build has been published yet. Check back soon.</p>"
    if rows:
        manifest = json.loads(base64.b64decode(json.loads(rows[0]["envelope"])["payload"]))
        download_url = manifest.get("installer_url") or manifest["launcher"]["url"]
        games_html = "".join(
            f"<p style='color:#80988d;font-size:15px'>{g['title']} v{g['package']['version']} &middot; {g.get('tagline','')}</p>"
            for g in manifest.get("games", [])
        )
        downloads = (
            f"<p><a href='{download_url}' style='color:#f1e8cd'>Download the launcher</a> "
            f"(v{manifest['launcher']['version']}, Windows) &mdash; installs and updates your games for you.</p>"
            + games_html
        )
    return HTMLResponse(
        "<html><title>Amiin Studio</title><body style='background:#102823;color:#f1e8cd;font:20px system-ui;"
        "max-width:800px;margin:100px auto;padding:0 20px'><p>AMIIN STUDIO</p><h1>Amiin Studio Launcher</h1>"
        "<p>One launcher. Your games, your worlds, your friends.</p>" + downloads +
        "<p style='color:#80988d;font-size:14px'>Create a free account in the launcher, then host or join an "
        "expedition with an invite code.</p></body></html>"
    )


if DEV:
    @app.get("/dev-download/{name}")
    def dev_download(name: str):
        if not re.fullmatch(r"[A-Za-z0-9_.-]+\.zip", name):
            raise HTTPException(404)
        path = Path("artifacts") / name
        if not path.is_file():
            raise HTTPException(404)
        return FileResponse(path)
