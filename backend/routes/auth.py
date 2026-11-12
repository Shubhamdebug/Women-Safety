import re

from flask import Blueprint, g, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

from auth_utils import create_token, token_required
from extensions import db
from models import User
from utils import error

bp = Blueprint("auth", __name__)
PHONE_RE = re.compile(r"^\+?\d{10,15}$")


@bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    name = str(data.get("name", "")).strip()
    phone = str(data.get("phone", "")).strip()
    password = str(data.get("password", ""))

    if not name:
        return error("Name is required.")
    if not PHONE_RE.match(phone):
        return error("Phone must be 10-15 digits (an optional + at the start is allowed).")
    if len(password) < 6:
        return error("Password must be at least 6 characters.")
    if User.query.filter_by(phone=phone).first():
        return error("This phone number is already registered.", 409)

    user = User(name=name, phone=phone, password_hash=generate_password_hash(password))
    db.session.add(user)
    db.session.commit()
    return jsonify({"token": create_token(user), "user": user.to_dict()}), 201


@bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    phone = str(data.get("phone", "")).strip()
    password = str(data.get("password", ""))

    user = User.query.filter_by(phone=phone).first()
    # Same message for both cases so attackers cannot find which phones exist.
    if user is None or not check_password_hash(user.password_hash, password):
        return error("Wrong phone number or password.", 401)
    return jsonify({"token": create_token(user), "user": user.to_dict()})


@bp.get("/me")
@token_required()
def me():
    return jsonify({"user": g.current_user.to_dict()})
