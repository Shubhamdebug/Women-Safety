"""
Tiny one-off schema fixes for an EXISTING database file (safeher.db).

db.create_all() only creates missing tables. It never changes a table that
already exists, so a database made before an SOS could be saved without a
location still has "latitude/longitude NOT NULL" on the incidents table.
SQLite cannot drop NOT NULL with ALTER TABLE, so the table is rebuilt (the
procedure recommended by the SQLite documentation). The data is copied across.
It runs at every start and does nothing if the table is already correct.
"""

_COLUMNS = (
    "id, user_id, kind, trigger, category, description, latitude, longitude, "
    "battery_level, status, photo_path, created_at, received_at"
)

_CREATE_NEW = """
CREATE TABLE incidents_new (
    id VARCHAR(36) NOT NULL,
    user_id INTEGER,
    kind VARCHAR(10) NOT NULL,
    trigger VARCHAR(20),
    category VARCHAR(30),
    description VARCHAR(500),
    latitude FLOAT,
    longitude FLOAT,
    battery_level INTEGER,
    status VARCHAR(15) NOT NULL,
    photo_path VARCHAR(255),
    created_at DATETIME,
    received_at DATETIME,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id)
)
"""


def allow_missing_incident_location(engine):
    """Make incidents.latitude/longitude optional in an old SQLite database."""
    if engine.dialect.name != "sqlite":
        return False
    raw = engine.raw_connection()
    try:
        cur = raw.cursor()
        info = cur.execute("PRAGMA table_info(incidents)").fetchall()
        # rows: (cid, name, type, notnull, default, pk)
        if not info or not any(r[1] in ("latitude", "longitude") and r[3] for r in info):
            return False  # table missing (new database) or already optional
        old_cols = {r[1] for r in info}
        wanted = [c.strip() for c in _COLUMNS.split(",")]
        if not set(wanted) <= old_cols:
            return False  # unknown older layout: do not touch it
        raw.isolation_level = None  # we control the transaction ourselves
        cur.execute("PRAGMA foreign_keys=OFF")
        cur.execute("BEGIN")
        try:
            cur.execute("DROP TABLE IF EXISTS incidents_new")
            cur.execute(_CREATE_NEW)
            cur.execute(f"INSERT INTO incidents_new ({_COLUMNS}) SELECT {_COLUMNS} FROM incidents")
            cur.execute("DROP TABLE incidents")
            cur.execute("ALTER TABLE incidents_new RENAME TO incidents")
            cur.execute("COMMIT")
        except Exception:
            cur.execute("ROLLBACK")
            raise
        finally:
            cur.execute("PRAGMA foreign_keys=ON")
        return True
    finally:
        raw.close()
