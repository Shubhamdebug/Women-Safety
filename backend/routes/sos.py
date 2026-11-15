import os
import uuid

from flask import Blueprint, current_app, g, jsonify, request

from alerts import dispatch_sos
from auth_utils import token_required
from extensions import db
from models import Incident, LocationPing
from utils import error, is_uuid, parse_ts, utcnow, valid_coords

bp = Blueprint("sos", __name__)

TRIGGERS = {"button", "shake", "low_battery", "timer", "voice", "other"}
FINAL_STATUSES = {"resolved", "cancelled", "false_alarm"}
PHOTO_EXT = {"jpg", "jpeg", "png"}


def _get_allowed_incident(incident_id):
    """Owner or admin may access. Returns (incident, error_response)."""
    incident = db.session.get(Incident, incident_id)
    user = g.current_user
    if incident is None or incident.kind != "sos":
        return None, error("SOS not found.", 404)
    if incident.user_id != user.id and user.role != "admin":
        return None, error("SOS not found.", 404)
    return incident, None


@bp.post("")
@token_required()
def create_sos():
    """
    The phone calls this when an SOS fires. The phone creates the 'id' (a UUID),
    so if it has to retry after a network drop the server does NOT create a duplicate.
    """
    user = g.current_user
    data = request.get_json(silent=True) or {}

    coords = valid_coords(data.get("latitude"), data.get("longitude"))
    if coords is None:
        return error("Valid latitude and longitude are required.")

    incident_id = data.get("id") or str(uuid.uuid4())
    if not is_uuid(incident_id):
        return error("'id' must be a UUID.")

    battery = data.get("battery_level")
    if battery is not None:
        if not isinstance(battery, int) or not 0 <= battery <= 100:
            return error("battery_level must be a whole number from 0 to 100.")

    trigger = data.get("trigger", "button")
    if trigger not in TRIGGERS:
        return error(f"trigger must be one of: {sorted(TRIGGERS)}")

    # Idempotency: same SOS sent twice (retry after reconnect) -> return the first one.
    existing = db.session.get(Incident, incident_id)
    if existing is not None:
        if existing.user_id != user.id:
            return error("This id is already used.", 409)
        return jsonify({"incident": existing.to_dict(), "duplicate": True}), 200

    incident = Incident(
        id=incident_id,
        user_id=user.id,
        kind="sos",
        trigger=trigger,
        latitude=coords[0],
        longitude=coords[1],
        battery_level=battery,
        status="active",
        created_at=parse_ts(data.get("timestamp")) or utcnow(),
        received_at=utcnow(),
    )
    db.session.add(incident)
    db.session.commit()  # STEP 1: save first. The SOS is now safe in the database.

    alerts = dispatch_sos(incident, user)  # STEP 2: delivery (can fail without losing step 1)
    return jsonify({"incident": incident.to_dict(), "alerts": alerts, "duplicate": False}), 201


@bp.get("/mine")
@token_required()
def my_sos():
    items = (
        Incident.query.filter_by(user_id=g.current_user.id, kind="sos")
        .order_by(Incident.received_at.desc())
        .limit(50)
        .all()
    )
    return jsonify({"incidents": [i.to_dict() for i in items]})


@bp.get("/<incident_id>")
@token_required()
def get_sos(incident_id):
    incident, err = _get_allowed_incident(incident_id)
    if err:
        return err
    data = incident.to_dict(include_user=True)
    data["pings"] = [p.to_dict() for p in sorted(incident.pings, key=lambda p: p.recorded_at)]
    data["alerts"] = [a.to_dict() for a in incident.alerts]
    return jsonify({"incident": data})


@bp.post("/<incident_id>/location")
@token_required()
def add_location(incident_id):
    """Continuous tracking: the phone sends a new point every few seconds while active."""
    incident, err = _get_allowed_incident(incident_id)
    if err:
        return err
    if incident.status != "active":
        return error("This SOS is no longer active.", 409)

    data = request.get_json(silent=True) or {}
    coords = valid_coords(data.get("latitude"), data.get("longitude"))
    if coords is None:
        return error("Valid latitude and longitude are required.")

    ping = LocationPing(
        incident_id=incident.id,
        latitude=coords[0],
        longitude=coords[1],
        recorded_at=parse_ts(data.get("timestamp")) or utcnow(),
    )
    db.session.add(ping)
    db.session.commit()
    return jsonify({"ping": ping.to_dict()}), 201


@bp.post("/<incident_id>/resolve")
@token_required()
def resolve_sos(incident_id):
    """User marks themselves safe / cancels / says it was a false alarm."""
    incident, err = _get_allowed_incident(incident_id)
    if err:
        return err
    data = request.get_json(silent=True) or {}
    status = data.get("status", "resolved")
    if status not in FINAL_STATUSES:
        return error(f"status must be one of: {sorted(FINAL_STATUSES)}")
    if incident.status != "active":
        return error("This SOS is already closed.", 409)

    incident.status = status
    db.session.commit()
    return jsonify({"incident": incident.to_dict()})


@bp.post("/<incident_id>/photo")
@token_required()
def upload_photo(incident_id):
    """Phone uploads the evidence photo when it is online. Send as multipart form, field 'photo'."""
    incident, err = _get_allowed_incident(incident_id)
    if err:
        return err
    file = request.files.get("photo")
    if file is None or file.filename == "":
        return error("Send the image in a form field named 'photo'.")
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in PHOTO_EXT:
        return error("Only jpg, jpeg or png images are allowed.")

    # We choose the file name ourselves, never trust the one the phone sends.
    filename = f"{incident.id}.{ext}"
    file.save(os.path.join(current_app.config["UPLOAD_FOLDER"], filename))
    incident.photo_path = filename
    db.session.commit()
    return jsonify({"incident": incident.to_dict()}), 201
