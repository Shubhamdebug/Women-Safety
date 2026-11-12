import uuid
from datetime import datetime, timezone

from flask import jsonify


def utcnow():
    """Current UTC time as a naive datetime (what SQLite stores)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def iso(dt):
    return dt.isoformat() + "Z" if dt else None


def parse_ts(value):
    """Parse an ISO-8601 timestamp from the phone. Returns naive UTC or None."""
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is not None:
        dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def valid_coords(lat, lon):
    """Return (lat, lon) as floats if valid, otherwise None."""
    try:
        lat, lon = float(lat), float(lon)
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return None
    return lat, lon


def is_uuid(value):
    try:
        uuid.UUID(str(value))
        return True
    except ValueError:
        return False


def error(message, status=400):
    return jsonify({"error": message}), status
