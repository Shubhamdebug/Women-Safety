import re

from flask import Blueprint, g, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

from auth_utils import create_token, token_required
from extensions import db, limiter
from models import User
from utils import error

bp = Blueprint("auth", __name__)
PHONE_RE = re.compile(r"^\+?\d{10,15}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


@bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    name = str(data.get("name", "")).strip()
    phone = str(data.get("phone", "")).strip()
    raw_email = data.get("email")
    email = str(raw_email).strip().lower() if raw_email is not None else ""
    password = str(data.get("password", ""))

    if not name:
        return error("Name is required.")
    if not PHONE_RE.match(phone):
        return error("Phone must be 10-15 digits (an optional + at the start is allowed).")
    if email and not EMAIL_RE.match(email):
        return error("Please enter a valid email address.")
    if len(password) < 6:
        return error("Password must be at least 6 characters.")
    if User.query.filter_by(phone=phone).first():
        return error("This phone number is already registered.", 409)
    if email and User.query.filter_by(email=email).first():
        return error("This email address is already registered.", 409)

    user = User(
        name=name,
        phone=phone,
        email=email or None,
        password_hash=generate_password_hash(password),
    )
    db.session.add(user)
    db.session.commit()
    return jsonify({"token": create_token(user), "user": user.to_dict()}), 201


@bp.post("/login")
@limiter.limit("10 per minute")
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


@bp.put("/me")
@token_required()
def update_me():
    data = request.get_json(silent=True) or {}
    user = g.current_user

    if "name" in data:
        name = str(data["name"]).strip()
        if not name:
            return error("Name cannot be empty.")
        user.name = name

    if "phone" in data:
        phone = str(data["phone"]).strip()
        if not PHONE_RE.match(phone):
            return error("Phone must be 10-15 digits (an optional + at the start is allowed).")
        existing = User.query.filter_by(phone=phone).first()
        if existing and existing.id != user.id:
            return error("This phone number is already registered.", 409)
        user.phone = phone

    if "email" in data:
        raw_email = data["email"]
        email = str(raw_email).strip().lower() if raw_email is not None else ""
        if email:
            if not EMAIL_RE.match(email):
                return error("Please enter a valid email address.")
            existing = User.query.filter_by(email=email).first()
            if existing and existing.id != user.id:
                return error("This email address is already registered.", 409)
            user.email = email
        else:
            user.email = None

    if "password" in data and data["password"]:
        password = str(data["password"])
        if len(password) < 6:
            return error("Password must be at least 6 characters.")
        user.password_hash = generate_password_hash(password)

    db.session.commit()
    return jsonify({"user": user.to_dict()})