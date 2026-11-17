import sqlite3

from migrations import allow_missing_incident_location
from app import create_app
from extensions import db


def _not_null(path):
    con = sqlite3.connect(path)
    rows = con.execute("PRAGMA table_info(incidents)").fetchall()
    con.close()
    return {r[1]: r[3] for r in rows}


def test_old_database_is_migrated_and_keeps_its_data(tmp_path):
    path = str(tmp_path / "old.db")
    con = sqlite3.connect(path)
    # the OLD layout: latitude/longitude NOT NULL, with child tables pointing at incidents
    con.executescript(
        """
        CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(80), phone VARCHAR(20));
        CREATE TABLE incidents (
            id VARCHAR(36) NOT NULL, user_id INTEGER, kind VARCHAR(10) NOT NULL,
            trigger VARCHAR(20), category VARCHAR(30), description VARCHAR(500),
            latitude FLOAT NOT NULL, longitude FLOAT NOT NULL, battery_level INTEGER,
            status VARCHAR(15) NOT NULL, photo_path VARCHAR(255),
            created_at DATETIME, received_at DATETIME,
            PRIMARY KEY (id), FOREIGN KEY(user_id) REFERENCES users (id));
        CREATE TABLE location_pings (
            id INTEGER PRIMARY KEY, incident_id VARCHAR(36) NOT NULL,
            latitude FLOAT NOT NULL, longitude FLOAT NOT NULL, recorded_at DATETIME,
            FOREIGN KEY(incident_id) REFERENCES incidents (id));
        INSERT INTO users VALUES (1, 'Old', '9111111111');
        INSERT INTO incidents (id, user_id, kind, trigger, latitude, longitude, status)
            VALUES ('11111111-1111-4111-8111-111111111111', 1, 'sos', 'button', 12.5, 77.5, 'active');
        INSERT INTO location_pings (incident_id, latitude, longitude)
            VALUES ('11111111-1111-4111-8111-111111111111', 12.6, 77.6);
        """
    )
    con.commit()
    con.close()
    assert _not_null(path)["latitude"] == 1

    app = create_app({"TESTING": True, "SQLALCHEMY_DATABASE_URI": f"sqlite:///{path}"})
    with app.app_context():
        pass  # create_app already ran the migration
    cols = _not_null(path)
    assert cols["latitude"] == 0 and cols["longitude"] == 0
    assert cols["kind"] == 1 and cols["status"] == 1  # the other rules are kept

    con = sqlite3.connect(path)
    assert con.execute("SELECT latitude, longitude FROM incidents").fetchall() == [(12.5, 77.5)]
    assert con.execute("SELECT COUNT(*) FROM location_pings").fetchone()[0] == 1
    # child table still points at "incidents" (not at a renamed leftover)
    fk = con.execute("PRAGMA foreign_key_list(location_pings)").fetchall()
    assert fk[0][2] == "incidents"
    # and a GPS-less SOS can now be stored
    con.execute("INSERT INTO incidents (id, kind, status) VALUES ('22222222-2222-4222-8222-222222222222', 'sos', 'active')")
    con.commit()
    con.close()


def test_migration_is_a_no_op_on_a_new_database():
    app = create_app({"TESTING": True, "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:"})
    with app.app_context():
        assert allow_missing_incident_location(db.engine) is False
