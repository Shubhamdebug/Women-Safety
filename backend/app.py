import os

from flask import Flask, jsonify
from flask_cors import CORS

from config import Config
from extensions import db, limiter


def create_app(config_overrides=None):
    app = Flask(__name__)
    app.config.from_object(Config)
    if config_overrides:
        app.config.update(config_overrides)
    os.makedirs(app.config["UPLOAD_FOLDER"], exist_ok=True)

    CORS(app)  # lets Charini's dashboard (another port) call this API
    db.init_app(app)
    limiter.init_app(app)

    from routes import admin, auth, guardians, reports, sos

    app.register_blueprint(auth.bp, url_prefix="/api/auth")
    app.register_blueprint(guardians.bp, url_prefix="/api/guardians")
    app.register_blueprint(sos.bp, url_prefix="/api/sos")
    app.register_blueprint(reports.bp, url_prefix="/api/reports")
    app.register_blueprint(admin.bp, url_prefix="/api/admin")

    with app.app_context():
        import models  # noqa: F401  (makes sure all tables are known)

        db.create_all()
        # Old databases: let an SOS be saved without a location (see migrations.py).
        from migrations import allow_missing_incident_location

        if allow_missing_incident_location(db.engine):
            print("[migration] incidents.latitude/longitude are now optional")

    @app.get("/api/health")
    def health():
        return jsonify({"status": "ok"})

    @app.errorhandler(404)
    def not_found(_):
        return jsonify({"error": "Route not found."}), 404

    @app.errorhandler(405)
    def wrong_method(_):
        return jsonify({"error": "Method not allowed."}), 405

    @app.errorhandler(413)
    def too_big(_):
        return jsonify({"error": "File too large (max 5 MB)."}), 413

    @app.errorhandler(429)
    def rate_limited(_):
        return jsonify({"error": "Too many requests. Please try again later."}), 429

    @app.errorhandler(500)
    def server_error(_):
        return jsonify({"error": "Something went wrong on the server."}), 500

    return app


if __name__ == "__main__":
    # Debug mode is OFF by default for safety on shared Wi-Fi; set FLASK_DEBUG=true only locally if needed.
    debug_mode = os.environ.get("FLASK_DEBUG", "false").lower() == "true"
    create_app().run(host="0.0.0.0", port=5000, debug=debug_mode)