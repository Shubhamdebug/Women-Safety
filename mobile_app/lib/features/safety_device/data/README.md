# Device adapters — implementation pending

Keep location, SQLite, accelerometer, SMS and network implementations here behind domain interfaces. No production adapter is supplied by this starter.

Do not add endpoint URLs or package versions by guesswork. Resolve compatible packages through Flutter and commit the resulting lockfile. Review each package's Android requirements before modifying the generated manifest.

Storage draft must be named and documented as provisional until Rishi's schema arrives. Development API fakes must never be selected silently for a real emergency flow. Tests using memory storage do not demonstrate restart durability.

## Integration notes (WSA app)

- This folder came from Vignesh's standalone handoff. Its `EmergencyEvent` has the same name as the one in `lib/models/models.dart`. Import one of them with a prefix (`import '...' as device;`) wherever both are needed, and map between them in an adapter. Do not send this model's `toJson()` to the backend: the backend has its own request format.
- Only send trigger values that the backend accepts (`TRIGGERS` in `backend/routes/sos.py`).
- Add Android permissions (location, foreground service, notifications) to `android/app/src/main/AndroidManifest.xml` of this app, not to the standalone shell.
