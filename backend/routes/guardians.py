import re

from flask import Blueprint, current_app, g, jsonify, request

from auth_utils import token_required
from extensions import db
from models import Guardian
from utils import error

bp = Blueprint("guardians", __name__)
PHONE_RE = re.compile(r"^\+?\d{10,15}$")


@bp.get("")
@token_required()
def list_guardians():
    return jsonify({"guardians": [x.to_dict() for x in g.current_user.guardians]})


@bp.post("")
@token_required()
def add_guardian():
    user = g.current_user
    data = request.get_json(silent=True) or {}
    name = str(data.get("name", "")).strip()
    phone = str(data.get("phone", "")).strip()
    relation = str(data.get("relation", "")).strip()[:50]

    if not name:
        return error("Guardian name is required.")
    if not PHONE_RE.match(phone):
        return error("Guardian phone must be 10-15 digits.")
    if len(user.guardians) >= current_app.config["MAX_GUARDIANS"]:
        return error(f"You can add at most {current_app.config['MAX_GUARDIANS']} guardians.", 409)

    guardian = Guardian(user_id=user.id, name=name, phone=phone, relation=relation)
    db.session.add(guardian)
    db.session.commit()
    return jsonify({"guardian": guardian.to_dict()}), 201


@bp.delete("/<int:guardian_id>")
@token_required()
def delete_guardian(guardian_id):
    guardian = db.session.get(Guardian, guardian_id)
    # Only the owner may delete. 404 (not 403) so IDs of other users are not revealed.
    if guardian is None or guardian.user_id != g.current_user.id:
        return error("Guardian not found.", 404)
    db.session.delete(guardian)
    db.session.commit()
    return jsonify({"deleted": guardian_id})
