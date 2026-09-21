"""Local publisher CLI. Signing keys never belong in game/launcher packages."""
import argparse, base64, hashlib, json, os, pathlib, re, zipfile
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding

ROOT=pathlib.Path(__file__).resolve().parent.parent
SECRETS=pathlib.Path(os.environ.get("LOCALAPPDATA",pathlib.Path.home()))/"AmiinStudioDeveloper"

def keygen(args):
    SECRETS.mkdir(parents=True,exist_ok=True)
    path=SECRETS/"release-signing.pem"
    if path.exists():raise SystemExit("Signing key already exists; refusing to replace it.")
    key=rsa.generate_private_key(public_exponent=65537,key_size=3072)
    path.write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
    public=key.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo).decode()
    (ROOT/"Launcher"/"release-public.pem").write_text(public)
    config=dict(api=args.api,publicKey=public,development=args.dev)
    (ROOT/"Launcher"/"launcher-config.json").write_text(json.dumps(config,indent=2))
    print("Signing key stored OUTSIDE the game project:",path)
    print("Back it up privately. Launcher configuration created.")

def package(path,version,url,entry):
    file=pathlib.Path(path)
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9._-]{0,39}",version):raise ValueError("Invalid version")
    with zipfile.ZipFile(file) as z:
        if entry not in z.namelist():raise ValueError("Executable missing: "+entry)
        if any(".." in name.split("/") or ":" in name or name.startswith(("/","\\")) for name in z.namelist()):raise ValueError("Unsafe ZIP")
    hasher=hashlib.sha256()
    with file.open("rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""):hasher.update(block)
    return dict(version=version,url=url,sha256=hasher.hexdigest(),size=file.stat().st_size,entry=entry)

def publish(args):
    # Releasing to preview never modifies public. Rollback is a NEW revision.
    import service
    if not re.fullmatch(r"[a-z0-9-]{1,32}",args.channel):raise ValueError("Invalid channel")
    old=service.query("SELECT envelope FROM releases WHERE channel=:c",c=args.channel)
    revision=1
    if old:revision=json.loads(base64.b64decode(json.loads(old[0]["envelope"])["payload"]))["revision"]+1
    manifest=dict(channel=args.channel,revision=revision,notes=args.notes,
                  launcher=package(args.launcher,args.launcher_version,args.launcher_url,"AmiinLauncher.exe"),
                  game=package(args.game,args.game_version,args.game_url,"VerdantWilds.exe"))
    payload=json.dumps(manifest,separators=(",",":"),sort_keys=True).encode()
    key=serialization.load_pem_private_key((SECRETS/"release-signing.pem").read_bytes(),password=None)
    signature=key.sign(payload,padding.PKCS1v15(),hashes.SHA256())
    envelope=json.dumps(dict(payload=base64.b64encode(payload).decode(),signature=base64.b64encode(signature).decode()))
    service.query("INSERT INTO releases VALUES (:c,:e,:v,1) ON CONFLICT(channel) DO UPDATE SET envelope=:e,game_version=:v,protocol=1",c=args.channel,e=envelope,v=args.game_version)
    print("Published ONLY",args.channel,"revision",revision,"game",args.game_version,"launcher",args.launcher_version)

def grant(args):
    import service
    if not re.fullmatch(r"[a-z0-9-]{1,32}",args.channel) or args.channel=="public":raise ValueError("Choose a named test channel")
    rows=service.query("SELECT id FROM accounts WHERE name=:n",n=args.username.lower())
    if not rows:raise ValueError("Create this account in the launcher first")
    service.query("INSERT INTO grants VALUES (:a,:c) ON CONFLICT DO NOTHING",a=rows[0]["id"],c=args.channel)
    print("Granted",args.username,"access to",args.channel)

if __name__=="__main__":
    p=argparse.ArgumentParser(); commands=p.add_subparsers(dest="command",required=True)
    k=commands.add_parser("keygen");k.add_argument("--api",required=True);k.add_argument("--dev",action="store_true");k.set_defaults(run=keygen)
    g=commands.add_parser("grant");g.add_argument("username");g.add_argument("channel");g.set_defaults(run=grant)
    r=commands.add_parser("publish");r.add_argument("--channel",required=True);r.add_argument("--notes",default="A new adventure awaits.")
    for kind in ("launcher","game"):
        r.add_argument("--"+kind,required=True);r.add_argument("--"+kind+"-version",required=True);r.add_argument("--"+kind+"-url",required=True)
    r.set_defaults(run=publish)
    args=p.parse_args();args.run(args)
