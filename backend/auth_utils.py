import functools
from datetime import timedelta

import jwt
from flask import current_app, g, request

from extensions import db
from models import User
from utils import error, utcnow


def create_token(user):
    payload = {
        "sub": str(user.id),
        "role": user.role,
        "exp": utcnow() + timedelta(hours=current_app.config["JWT_EXPIRY_HOURS"]),
    }
    return jwt.encode(payload, current_app.config["SECRET_KEY"], algorithm="HS256")


def token_required(roles=None):
    """Protect a route. Use @token_required() or @token_required(roles=["admin"])."""

    def decorator(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            header = request.headers.get("Authorization", "")
            if not header.startswith("Bearer "):
                return error("Missing token. Send 'Authorization: Bearer <token>'.", 401)
            try:
                payload = jwt.decode(
                    header[7:], current_app.config["SECRET_KEY"], algorithms=["HS256"]
                )
            except jwt.ExpiredSignatureError:
                return error("Token expired. Please log in again.", 401)
            except jwt.InvalidTokenError:
                return error("Invalid token.", 401)

            user = db.session.get(User, int(payload["sub"]))
            if user is None:
                return error("User no longer exists.", 401)
            if roles and user.role not in roles:
                return error("You do not have permission for this action.", 403)

            g.current_user = user
            return fn(*args, **kwargs)

        return wrapper

    return decorator
