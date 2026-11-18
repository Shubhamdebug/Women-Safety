import tempfile
import uuid

import pytest
from werkzeug.security import generate_password_hash

from app import create_app
from extensions import db
from models import AlertLog, Incident, User


@pytest.fixture()
def client():
    app = create_app(
        {
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
            "UPLOAD_FOLDER": tempfile.mkdtemp(),
        }
    )
    with app.app_context():
        db.session.add(
            User(name="Admin", phone="9000000000", password_hash=generate_password_hash("admin123"), role="admin")
        )
        db.session.commit()
    with app.test_client() as c:
        c.app = app
        yield c


def register(client, phone="9876543210", name="Asha"):
    r = client.post("/api/auth/register", json={"name": name, "phone": phone, "password": "secret123"})
    assert r.status_code == 201
    return {"Authorization": f"Bearer {r.get_json()['token']}"}


def admin_headers(client):
    r = client.post("/api/auth/login", json={"phone": "9000000000", "password": "admin123"})
    return {"Authorization": f"Bearer {r.get_json()['token']}"}


# ---------- auth ----------
def test_register_login_me(client):
    headers = register(client)
    assert client.get("/api/auth/me", headers=headers).get_json()["user"]["name"] == "Asha"
    r = client.post("/api/auth/login", json={"phone": "9876543210", "password": "secret123"})
    assert r.status_code == 200 and "token" in r.get_json()


def test_register_validation_and_duplicate(client):
    assert client.post("/api/auth/register", json={"name": "", "phone": "123", "password": "x"}).status_code == 400
    register(client)
    r = client.post("/api/auth/register", json={"name": "B", "phone": "9876543210", "password": "secret123"})
    assert r.status_code == 409


def test_wrong_password_and_missing_token(client):
    register(client)
    assert client.post("/api/auth/login", json={"phone": "9876543210", "password": "nope"}).status_code == 401
    assert client.get("/api/guardians").status_code == 401


def test_password_is_hashed(client):
    register(client)
    with client.app.app_context():
        user = User.query.filter_by(phone="9876543210").first()
        assert user.password_hash != "secret123"


# ---------- guardians ----------
def test_guardian_crud_and_ownership(client):
    h1 = register(client)
    h2 = register(client, phone="9111111111", name="Other")
    r = client.post("/api/guardians", json={"name": "Mom", "phone": "9822222222", "relation": "mother"}, headers=h1)
    gid = r.get_json()["guardian"]["id"]
    assert len(client.get("/api/guardians", headers=h1).get_json()["guardians"]) == 1
    assert client.delete(f"/api/guardians/{gid}", headers=h2).status_code == 404  # not the owner
    assert client.delete(f"/api/guardians/{gid}", headers=h1).status_code == 200


# ---------- SOS ----------
def test_sos_flow_alerts_and_idempotency(client):
    h = register(client)
    client.post("/api/guardians", json={"name": "Mom", "phone": "9822222222"}, headers=h)
    client.post("/api/guardians", json={"name": "Friend", "phone": "9833333333"}, headers=h)

    sos_id = str(uuid.uuid4())
    body = {"id": sos_id, "latitude": 16.70, "longitude": 74.24, "battery_level": 14, "trigger": "low_battery"}
    r = client.post("/api/sos", json=body, headers=h)
    assert r.status_code == 201
    assert r.get_json()["duplicate"] is False
    assert len(r.get_json()["alerts"]) == 3  # 2 guardians + dashboard

    # Same SOS sent again (phone retried after reconnect): no duplicate, no second alert.
    r2 = client.post("/api/sos", json=body, headers=h)
    assert r2.status_code == 200 and r2.get_json()["duplicate"] is True
    with client.app.app_context():
        assert Incident.query.count() == 1
        assert AlertLog.query.count() == 3


def test_sos_validation(client):
    h = register(client)
    assert client.post("/api/sos", json={"latitude": 999, "longitude": 0}, headers=h).status_code == 400
    assert client.post("/api/sos", json={"latitude": 1, "longitude": 1, "battery_level": 500}, headers=h).status_code == 400
    assert client.post("/api/sos", json={"latitude": 1, "longitude": 1, "trigger": "magic"}, headers=h).status_code == 400
    assert client.post("/api/sos", json={"latitude": 1, "longitude": 1}).status_code == 401


def test_sos_tracking_and_resolve(client):
    h = register(client)
    sos_id = client.post("/api/sos", json={"latitude": 16.7, "longitude": 74.2}, headers=h).get_json()["incident"]["id"]
    assert client.post(f"/api/sos/{sos_id}/location", json={"latitude": 16.71, "longitude": 74.21}, headers=h).status_code == 201
    detail = client.get(f"/api/sos/{sos_id}", headers=h).get_json()["incident"]
    assert len(detail["pings"]) == 1

    assert client.post(f"/api/sos/{sos_id}/resolve", json={"status": "false_alarm"}, headers=h).status_code == 200
    # closed SOS cannot be updated again
    assert client.post(f"/api/sos/{sos_id}/location", json={"latitude": 1, "longitude": 1}, headers=h).status_code == 409
    assert client.post(f"/api/sos/{sos_id}/resolve", json={"status": "resolved"}, headers=h).status_code == 409


def test_cannot_see_someone_elses_sos(client):
    h1 = register(client)
    h2 = register(client, phone="9111111111", name="Other")
    sos_id = client.post("/api/sos", json={"latitude": 16.7, "longitude": 74.2}, headers=h1).get_json()["incident"]["id"]
    assert client.get(f"/api/sos/{sos_id}", headers=h2).status_code == 404
    assert client.get(f"/api/sos/{sos_id}", headers=admin_headers(client)).status_code == 200


def test_photo_upload(client):
    import io

    h = register(client)
    sos_id = client.post("/api/sos", json={"latitude": 16.7, "longitude": 74.2}, headers=h).get_json()["incident"]["id"]
    ok = client.post(
        f"/api/sos/{sos_id}/photo",
        data={"photo": (io.BytesIO(b"fakeimagebytes"), "evidence.jpg")},
        headers=h,
        content_type="multipart/form-data",
    )
    assert ok.status_code == 201 and ok.get_json()["incident"]["has_photo"] is True
    bad = client.post(
        f"/api/sos/{sos_id}/photo",
        data={"photo": (io.BytesIO(b"x"), "virus.exe")},
        headers=h,
        content_type="multipart/form-data",
    )
    assert bad.status_code == 400


# ---------- anonymous reports ----------
def test_anonymous_report_has_no_user(client):
    r = client.post("/api/reports", json={"category": "poor_lighting", "latitude": 16.7, "longitude": 74.2})
    assert r.status_code == 201
    with client.app.app_context():
        report = Incident.query.first()
        assert report.kind == "report" and report.user_id is None


def test_report_validation(client):
    assert client.post("/api/reports", json={"category": "nonsense", "latitude": 1, "longitude": 1}).status_code == 400
    assert client.post("/api/reports", json={"category": "other", "latitude": "x", "longitude": 1}).status_code == 400


def test_logged_in_user_report_is_still_anonymous(client):
    h = register(client)  # even with a valid token, the report must stay anonymous
    client.post("/api/reports", json={"category": "harassment", "latitude": 16.7, "longitude": 74.2}, headers=h)
    with client.app.app_context():
        assert Incident.query.first().user_id is None


# ---------- admin ----------
def test_admin_endpoints_are_protected(client):
    user_h = register(client)
    for path in ("/api/admin/incidents", "/api/admin/hotspots", "/api/admin/stats"):
        assert client.get(path).status_code == 401
        assert client.get(path, headers=user_h).status_code == 403
        assert client.get(path, headers=admin_headers(client)).status_code == 200


def test_admin_feed_hotspots_and_stats(client):
    h = register(client)
    client.post("/api/sos", json={"latitude": 16.7000, "longitude": 74.2400}, headers=h)
    for _ in range(5):
        client.post("/api/reports", json={"category": "poor_lighting", "latitude": 16.7001, "longitude": 74.2401})

    a = admin_headers(client)
    feed = client.get("/api/admin/incidents", headers=a).get_json()["incidents"]
    assert len(feed) == 6
    sos_item = next(i for i in feed if i["kind"] == "sos")
    report_item = next(i for i in feed if i["kind"] == "report")
    assert "user" in sos_item and "user" not in report_item  # reports stay anonymous on the dashboard

    only_sos = client.get("/api/admin/incidents?kind=sos", headers=a).get_json()["incidents"]
    assert len(only_sos) == 1

    spots = client.get("/api/admin/hotspots", headers=a).get_json()
    assert spots["total_incidents"] == 6
    assert spots["hotspots"][0]["incident_count"] == 6
    assert spots["hotspots"][0]["risk_level"] == "medium"
    assert "user" not in spots["hotspots"][0]

    stats = client.get("/api/admin/stats", headers=a).get_json()
    assert stats["by_kind"] == {"sos": 1, "report": 5}
    assert stats["by_category"] == {"poor_lighting": 5}


def test_health_and_404(client):
    assert client.get("/api/health").get_json() == {"status": "ok"}
    assert client.get("/api/nope").status_code == 404
