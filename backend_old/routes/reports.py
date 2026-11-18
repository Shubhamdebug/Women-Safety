import uuid

from flask import Blueprint, jsonify, request

from extensions import db
from models import Incident
from utils import error, parse_ts, utcnow, valid_coords

bp = Blueprint("reports", __name__)

CATEGORIES = [
    "harassment",
    "stalking",
    "suspicious_activity",
    "poor_lighting",
    "unsafe_area",
    "other",
]


@bp.get("/categories")
def categories():
    return jsonify({"categories": CATEGORIES})


@bp.post("")
def create_report():
    """
    ANONYMOUS reporting. Deliberately NO @token_required here, and we never read the
    Authorization header, the IP address or any user info. user_id stays NULL.
    """
    data = request.get_json(silent=True) or {}

    category = data.get("category")
    if category not in CATEGORIES:
        return error(f"category must be one of: {CATEGORIES}")

    coords = valid_coords(data.get("latitude"), data.get("longitude"))
    if coords is None:
        return error("Valid latitude and longitude are required.")

    description = str(data.get("description", "")).strip()[:500]

    report = Incident(
        id=str(uuid.uuid4()),
        user_id=None,  # <- this is what makes it anonymous
        kind="report",
        category=category,
        description=description,
        latitude=coords[0],
        longitude=coords[1],
        status="logged",
        created_at=parse_ts(data.get("timestamp")) or utcnow(),
        received_at=utcnow(),
    )
    db.session.add(report)
    db.session.commit()
    return jsonify({"report": {"id": report.id, "category": category, "status": "logged"}}), 201
