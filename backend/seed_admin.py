"""
Create an admin account for the dashboard (Charini needs one to log in).

Run:  python seed_admin.py 9999999999 admin123
"""
import sys

from werkzeug.security import generate_password_hash

from app import create_app
from extensions import db
from models import User

if len(sys.argv) != 3:
    print("Usage: python seed_admin.py <phone> <password>")
    sys.exit(1)

phone, password = sys.argv[1], sys.argv[2]
app = create_app()
with app.app_context():
    user = User.query.filter_by(phone=phone).first()
    if user:
        user.role = "admin"
        print(f"Existing user {phone} is now an admin.")
    else:
        db.session.add(
            User(name="Campus Admin", phone=phone, password_hash=generate_password_hash(password), role="admin")
        )
        print(f"Admin created. Log in with phone {phone}.")
    db.session.commit()
