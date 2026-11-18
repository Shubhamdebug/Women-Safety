"""
Alert routing: when an SOS arrives, tell every guardian and log it for the dashboard.

Two modes:
  * SIMULATED (default): message is printed in the terminal and saved in alert_logs.
    Good for demos and testing, costs nothing.
  * TWILIO: real SMS. Turns on automatically if the TWILIO_* settings are filled in
    and the 'twilio' package is installed (pip install twilio).
"""
from flask import current_app

from extensions import db
from models import AlertLog


def build_message(user, incident):
    link = f"https://maps.google.com/?q={incident.latitude},{incident.longitude}"
    battery = f" Battery: {incident.battery_level}%." if incident.battery_level is not None else ""
    return f"SafeHer ALERT: {user.name} may need help. Location: {link}.{battery}"


def _send_sms(phone, text):
    """Returns (status, detail)."""
    cfg = current_app.config
    if cfg["TWILIO_ACCOUNT_SID"] and cfg["TWILIO_AUTH_TOKEN"] and cfg["TWILIO_FROM_NUMBER"]:
        from twilio.rest import Client  # imported only when really needed

        client = Client(cfg["TWILIO_ACCOUNT_SID"], cfg["TWILIO_AUTH_TOKEN"])
        msg = client.messages.create(body=text, from_=cfg["TWILIO_FROM_NUMBER"], to=phone)
        return "sent", f"twilio sid {msg.sid}"

    print(f"[SIMULATED SMS] to {phone}: {text}")
    return "simulated", "twilio not configured"


def dispatch_sos(incident, user):
    """
    Send alerts to all guardians. One failed SMS never stops the others, and a
    failure never undoes the saved incident (storage and delivery are separate).
    """
    text = build_message(user, incident)
    results = []

    for guardian in user.guardians:
        try:
            status, detail = _send_sms(guardian.phone, text)
        except Exception as exc:  # network down, bad number, etc.
            status, detail = "failed", str(exc)[:250]
        log = AlertLog(
            incident_id=incident.id,
            guardian_id=guardian.id,
            channel="sms",
            status=status,
            detail=detail,
        )
        db.session.add(log)
        results.append({"guardian": guardian.name, "channel": "sms", "status": status})

    # The admin dashboard reads incidents directly, so this is just an audit entry.
    db.session.add(
        AlertLog(incident_id=incident.id, channel="dashboard", status="sent", detail="visible on dashboard")
    )
    results.append({"guardian": None, "channel": "dashboard", "status": "sent"})

    db.session.commit()
    return results
