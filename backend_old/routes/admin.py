from collections import Counter, defaultdict
from datetime import timedelta

from flask import Blueprint, jsonify, request

from auth_utils import token_required
from models import Incident
from utils import error, iso, parse_ts, utcnow

bp = Blueprint("admin", __name__)

IST_OFFSET_MIN = 330  # India Standard Time = UTC + 5:30


def _local_hour(dt, offset_min):
    return (dt + timedelta(minutes=offset_min)).hour


@bp.get("/incidents")
@token_required(roles=["admin"])
def list_incidents():
    """
    Live feed for the dashboard. Poll every few seconds with ?since=<last received_at>
    to get only new items. Filters: kind=sos|report, status=active|...
    """
    query = Incident.query
    kind = request.args.get("kind")
    status = request.args.get("status")
    if kind:
        query = query.filter_by(kind=kind)
    if status:
        query = query.filter_by(status=status)

    since = parse_ts(request.args.get("since"))
    if request.args.get("since") and since is None:
        return error("'since' must be an ISO timestamp like 2025-01-31T10:00:00Z.")
    if since:
        query = query.filter(Incident.received_at > since)

    try:
        limit = min(int(request.args.get("limit", 100)), 500)
    except ValueError:
        return error("limit must be a number.")

    items = query.order_by(Incident.received_at.desc()).limit(limit).all()
    # include_user only matters for SOS. Reports have no user, so they stay anonymous.
    return jsonify({"incidents": [i.to_dict(include_user=True) for i in items]})


@bp.get("/hotspots")
@token_required(roles=["admin"])
def hotspots():
    """
    Groups incidents into map-grid cells. Uses ONLY location and time, never identity.
    Query: days=30 (look-back), cell=0.001 (about 110 m), tz_offset=330 (minutes).
    """
    try:
        days = int(request.args.get("days", 30))
        cell = float(request.args.get("cell", 0.001))
        tz_offset = int(request.args.get("tz_offset", IST_OFFSET_MIN))
    except ValueError:
        return error("days, cell and tz_offset must be numbers.")
    if cell <= 0:
        return error("cell must be greater than 0.")

    cutoff = utcnow() - timedelta(days=days)
    items = Incident.query.filter(Incident.created_at >= cutoff).all()

    cells = defaultdict(lambda: {"count": 0, "lat": 0.0, "lon": 0.0, "hours": Counter()})
    for inc in items:
        key = (round(inc.latitude / cell), round(inc.longitude / cell))
        c = cells[key]
        c["count"] += 1
        c["lat"] += inc.latitude
        c["lon"] += inc.longitude
        c["hours"][_local_hour(inc.created_at, tz_offset)] += 1

    result = []
    for (ix, iy), c in cells.items():
        count = c["count"]
        risk = "high" if count >= 10 else "medium" if count >= 5 else "low"
        result.append(
            {
                "cluster_id": f"{ix}_{iy}",
                "latitude": c["lat"] / count,
                "longitude": c["lon"] / count,
                "incident_count": count,
                "risk_level": risk,
                "peak_hour": c["hours"].most_common(1)[0][0],
            }
        )
    result.sort(key=lambda r: r["incident_count"], reverse=True)
    return jsonify({"hotspots": result, "total_incidents": len(items)})


@bp.get("/stats")
@token_required(roles=["admin"])
def stats():
    try:
        tz_offset = int(request.args.get("tz_offset", IST_OFFSET_MIN))
    except ValueError:
        return error("tz_offset must be a number.")

    items = Incident.query.all()
    last_24h = utcnow() - timedelta(hours=24)
    return jsonify(
        {
            "total": len(items),
            "by_kind": dict(Counter(i.kind for i in items)),
            "by_status": dict(Counter(i.status for i in items)),
            "by_category": dict(Counter(i.category for i in items if i.category)),
            "by_hour": dict(sorted(Counter(_local_hour(i.created_at, tz_offset) for i in items).items())),
            "last_24h": sum(1 for i in items if i.received_at >= last_24h),
            "generated_at": iso(utcnow()),
        }
    )
