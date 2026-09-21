import os
import tempfile
os.environ["DATABASE_URL"] = "sqlite:///" + tempfile.mktemp(suffix=".db")
os.environ["AMIIN_DEV"] = "1"
import struct
import pytest
from fastapi.testclient import TestClient
import service

client = TestClient(service.app)

def account(name):
    result = client.post("/auth/register", json={"username":name,"password":"Correct-Horse-Cloud-97"})
    assert result.status_code == 200, result.text
    token = result.json()["token"]
    headers = {"Authorization":"Bearer " + token}
    ticket = client.post("/auth/launch-ticket", headers=headers).json()["ticket"]
    token = client.post("/auth/exchange", headers={"Authorization":"Bearer " + ticket}).json()["token"]
    assert client.post("/auth/exchange", headers={"Authorization":"Bearer " + ticket}).status_code == 401
    return {"Authorization":"Bearer " + token}

def test_accounts_channels_versions_and_relay():
    h = account("host_test")
    g = account("guest_test")
    build = {"version":"dev","channel":"public","protocol":1}
    assert client.post("/rooms", json=build).status_code == 401
    assert client.post("/rooms", headers=h, json={**build,"channel":"preview"}).status_code == 403
    assert client.post("/rooms", headers=h, json={**build,"version":"old"}).status_code == 409
    room = client.post("/rooms", headers=h, json=build).json()
    with client.websocket_connect("/relay", headers={"Authorization":"Bearer " + room["ticket"]}) as host:
        assert host.receive_json()["id"] == 1
        guest = client.post("/rooms/" + room["code"] + "/join", headers=g, json=build).json()
        with client.websocket_connect("/relay", headers={"Authorization":"Bearer " + guest["ticket"]}) as join:
            ready = join.receive_json()
            assert ready["peers"][0]["username"] == "host_test"
            assert host.receive_json()["peer"]["username"] == "guest_test"
            join.send_bytes(struct.pack("<ii",1,0)+b"intent")
            assert host.receive_bytes() == struct.pack("<ii",guest["peer_id"],0)+b"intent"
            host.send_bytes(struct.pack("<ii",guest["peer_id"],0)+b"snapshot")
            assert join.receive_bytes() == struct.pack("<ii",1,0)+b"snapshot"
            join.send_bytes(struct.pack("<ii",0,0)+b"spoof broadcast")
            with pytest.raises(Exception): join.receive_bytes()
    assert client.post("/rooms/"+room["code"]+"/join", headers=g,json=build).status_code == 404

def test_login_logout_recovery():
    # Reset limiter between independent cases; it is intentionally tight.
    service.limits.clear()
    data={"username":"recover_me","password":"Correct-Horse-Cloud-97"}
    registered=client.post("/auth/register",json=data).json()
    assert client.post("/auth/login",json={**data,"password":"incorrect-long-password"}).status_code==401
    headers={"Authorization":"Bearer "+registered["token"]}
    assert client.get("/auth/me",headers=headers).status_code==200
    assert client.post("/auth/recover",json={**data,"password":"New-Password-for-testing","recovery_code":registered["recovery_code"]}).status_code==200
    assert client.get("/auth/me",headers=headers).status_code==401
    assert client.post("/auth/login",json=data).status_code==401
