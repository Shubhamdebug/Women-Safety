"""
Database models. These follow the class diagram from the presentation:
User, Guardian, Incident (+ Hotspot, which is calculated from incidents).

NOTE FOR RISHI (Database owner): this file is the shared contract. If you
change a table or column name, tell Tanisha so the API code can be updated.
"""
from extensions import db
from utils import iso, utcnow


class User(db.Model):
    __tablename__ = "users"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)  # never plain text
    role = db.Column(db.String(10), nullable=False, default="user")  # user | admin
    created_at = db.Column(db.DateTime, default=utcnow)

    guardians = db.relationship(
        "Guardian", backref="user", cascade="all, delete-orphan"
    )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "phone": self.phone,
            "role": self.role,
        }


class Guardian(db.Model):
    __tablename__ = "guardians"
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    relation = db.Column(db.String(50), default="")

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "phone": self.phone,
            "relation": self.relation,
        }


class Incident(db.Model):
    """One SOS or one anonymous report. user_id is NULL for anonymous reports."""

    __tablename__ = "incidents"
    id = db.Column(db.String(36), primary_key=True)  # UUID made on the phone
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    kind = db.Column(db.String(10), nullable=False)  # sos | report
    trigger = db.Column(db.String(20))  # button | shake | low_battery | timer | voice
    category = db.Column(db.String(30))  # used by reports
    description = db.Column(db.String(500))
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    battery_level = db.Column(db.Integer)
    status = db.Column(db.String(15), nullable=False, default="active")
    photo_path = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=utcnow)  # time on the phone
    received_at = db.Column(db.DateTime, default=utcnow)  # time server got it

    user = db.relationship("User")
    pings = db.relationship(
        "LocationPing", backref="incident", cascade="all, delete-orphan"
    )
    alerts = db.relationship(
        "AlertLog", backref="incident", cascade="all, delete-orphan"
    )

    def to_dict(self, include_user=False):
        data = {
            "id": self.id,
            "kind": self.kind,
            "trigger": self.trigger,
            "category": self.category,
            "description": self.description,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "battery_level": self.battery_level,
            "status": self.status,
            "has_photo": bool(self.photo_path),
            "created_at": iso(self.created_at),
            "received_at": iso(self.received_at),
        }
        if include_user and self.user:
            data["user"] = {"id": self.user.id, "name": self.user.name, "phone": self.user.phone}
        return data


class LocationPing(db.Model):
    """Continuous tracking points while an SOS is active."""

    __tablename__ = "location_pings"
    id = db.Column(db.Integer, primary_key=True)
    incident_id = db.Column(db.String(36), db.ForeignKey("incidents.id"), nullable=False)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    recorded_at = db.Column(db.DateTime, default=utcnow)

    def to_dict(self):
        return {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "recorded_at": iso(self.recorded_at),
        }


class AlertLog(db.Model):
    """Record of every alert we tried to send (audit trail)."""

    __tablename__ = "alert_logs"
    id = db.Column(db.Integer, primary_key=True)
    incident_id = db.Column(db.String(36), db.ForeignKey("incidents.id"), nullable=False)
    guardian_id = db.Column(db.Integer, db.ForeignKey("guardians.id"), nullable=True)
    channel = db.Column(db.String(15), nullable=False)  # sms | dashboard
    status = db.Column(db.String(15), nullable=False)  # sent | simulated | failed
    detail = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=utcnow)

    def to_dict(self):
        return {
            "channel": self.channel,
            "status": self.status,
            "guardian_id": self.guardian_id,
            "detail": self.detail,
            "created_at": iso(self.created_at),
        }
