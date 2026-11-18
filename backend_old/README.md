# SafeHer Backend — Tanisha's Guide (Member 3: Backend Core)

This is a **working** Flask backend. It already passes 16 automated tests. Your job is to
get it running, understand it, test it, share it with the team, and then improve it.

**Your role (from the team charter):** build the REST APIs, handle secure user
authentication, and route emergency alerts to the right contacts and dashboards.

---

## PART A — Get it running (about 20 minutes)

### Step 1: Install the tools (from the "Software Every Team Member Needs" sheet)
- Python 3 (tick **"Add Python to PATH"** during install)
- Git, VS Code, Chrome
- Postman
- Check in a terminal: `python --version` and `git --version`

### Step 2: Put the code in the team GitHub repo
1. Create the folder `backend/` inside the team repo and copy all these files into it.
2. In the terminal:
   ```
   cd <your-repo>
   git checkout -b backend-api
   git add backend
   git commit -m "Add Flask backend: auth, guardians, SOS, reports, admin"
   git push -u origin backend-api
   ```
3. Open a Pull Request on GitHub and ask Lalit to review it.

### Step 3: Create a virtual environment and install packages
Open a terminal **inside the backend folder**.

**Windows**
```
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```
**Mac / Linux**
```
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```
You should see `(venv)` at the start of the terminal line. Always activate it before working.

### Step 4: Run the tests (proves your setup is correct)
```
python -m pytest
```
Expected: `16 passed`. If something fails, read the message, or send it to me.

### Step 5: Create the admin account (Charini needs this to log in)
```
python seed_admin.py 9999999999 admin123
```

### Step 6: Start the server
```
python app.py
```
Open `http://127.0.0.1:5000/api/health` in Chrome. You should see `{"status": "ok"}`.
Leave this terminal running while you test.

### Step 7: Test every endpoint with Postman
1. Postman → **Import** → choose `SafeHer.postman_collection.json`.
2. Run the requests **in folder order** (Health → Auth → Guardians → SOS → Reports → Admin).
3. `Register`, `Login`, `Create SOS` and `Admin login` automatically save the token / SOS id,
   so later requests just work.
4. Look at the terminal where the server runs. After "Create SOS" you will see a line like
   `[SIMULATED SMS] to 9822222222: SafeHer ALERT: Asha may need help...`
   That is the alert routing working. No SMS is really sent in this mode.

### Step 8: Let the phone reach your laptop (this causes problems later if skipped)
- Laptop and Vignesh's phone must be on the **same Wi-Fi**.
- Find your laptop IP: Windows `ipconfig` (look for IPv4), Mac/Linux `ifconfig` / `ip a`. Example: `192.168.1.8`.
- The app must call `http://192.168.1.8:5000`, **not** `localhost` (on a phone, localhost means the phone itself).
- If it still cannot connect, allow Python through the Windows Firewall (private network).
- Tell Shubham and Vignesh your IP and port **now**.

### Step 9: Share the API contract
Send the **API reference below** to Shubham, Vignesh and Charini. They build against it.
Tell Charini the admin login (phone `9999999999`, password `admin123`).

### Step 10: Coordinate with Rishi (Database)
`models.py` is the database contract. Ask Rishi to review it. If he renames a column, update
the code together. Do not edit tables separately or the app will break.

---

## PART B — Your remaining work (Phase 2 → Phase 3)

| # | Task | Why it matters |
|---|------|----------------|
| 1 | Review each file and be able to explain it (see "How the code is organised") | Sir may ask you |
| 2 | Agree final field names with Shubham and Vignesh using the API reference | Prevents integration bugs |
| 3 | Optional: real SMS with Twilio (see below) | Better demo |
| 4 | Add features from "Ideas to improve" | Extra marks |
| 5 | Phase 3: connect Flutter app and dashboard to this live backend; help Lalit with end-to-end tests | Final integration |
| 6 | Before the final demo: change `SECRET_KEY` and delete `safeher.db` for a clean start | Security and tidy demo |

### Optional: real SMS with Twilio
1. Create a Twilio trial account; note Account SID, Auth Token and a phone number.
2. `pip install twilio`
3. Set the three `TWILIO_*` values from `.env.example` as environment variables
   (Windows: `set TWILIO_ACCOUNT_SID=...`, Mac/Linux: `export TWILIO_ACCOUNT_SID=...`).
4. Restart the server. On a trial account you can only SMS numbers you have verified in Twilio.

---

## How the code is organised

| File | What it does |
|------|--------------|
| `app.py` | Creates the app, registers all route groups, starts the server |
| `config.py` | Settings (secret key, database path, limits) |
| `models.py` | Database tables: User, Guardian, Incident, LocationPing, AlertLog |
| `auth_utils.py` | Makes and checks login tokens (JWT); `@token_required` protects a route |
| `alerts.py` | Sends the SOS alert to every guardian and logs it |
| `routes/auth.py` | Register, login, who-am-I |
| `routes/guardians.py` | Add / list / delete emergency contacts |
| `routes/sos.py` | Create SOS, live location, resolve/cancel, photo |
| `routes/reports.py` | Anonymous incident reports |
| `routes/admin.py` | Dashboard feed, hotspots, stats (admin only) |
| `seed_admin.py` | Creates the admin login |
| `tests/test_api.py` | 16 automated tests |

### Design decisions you can explain to sir
- **Passwords are hashed**, never stored as plain text.
- **JWT tokens** prove who is calling; admin routes check the `admin` role.
- **SOS is saved first, then alerts are sent.** If an SMS fails, the SOS is still safely stored.
  This matches the "storage and delivery are separate outcomes" slide.
- **The phone creates the SOS id (UUID).** If it retries after a network drop, the server
  recognises it and does not create a duplicate. This is how "no SOS is dropped" works.
- **Anonymous reports ignore the login token, IP and user info.** `user_id` stays empty.
- **Hotspots use only location and time**, never identity.
- Users can only see their own SOS and guardians; admins can see all.

---

## API REFERENCE (share this with the team)

Base URL: `http://<laptop-ip>:5000` · All bodies are JSON · Protected routes need the header
`Authorization: Bearer <token>`

### Auth
| Method | Path | Body | Returns |
|---|---|---|---|
| POST | `/api/auth/register` | `name, phone, password` (min 6) | `token, user` (201) |
| POST | `/api/auth/login` | `phone, password` | `token, user` |
| GET | `/api/auth/me` 🔒 | — | `user` |

### Guardians (emergency contacts) 🔒
| Method | Path | Body |
|---|---|---|
| GET | `/api/guardians` | — |
| POST | `/api/guardians` | `name, phone, relation` (max 5 per user) |
| DELETE | `/api/guardians/<id>` | — |

### SOS 🔒 (for Shubham and Vignesh)
| Method | Path | Body / notes |
|---|---|---|
| POST | `/api/sos` | `id` (UUID made on the phone), `latitude`, `longitude`, `battery_level` (0-100), `trigger` (`button`/`shake`/`low_battery`/`timer`/`voice`/`other`), `timestamp` (ISO, optional). Alerts guardians. Same `id` sent again returns `duplicate: true`, no second alert. |
| POST | `/api/sos/<id>/location` | `latitude, longitude, timestamp` — send every few seconds while active |
| POST | `/api/sos/<id>/resolve` | `status`: `resolved` / `cancelled` / `false_alarm` |
| POST | `/api/sos/<id>/photo` | multipart form, field name `photo` (jpg/png, max 5 MB) |
| GET | `/api/sos/<id>` | details, location points, alert log |
| GET | `/api/sos/mine` | the user's own SOS history |

**Offline sync (Vignesh):** save the SOS on the phone with its own UUID. When internet returns,
send it to `POST /api/sos` using the same `id` and the original `timestamp`.

### Anonymous reports (no login needed)
| Method | Path | Body |
|---|---|---|
| GET | `/api/reports/categories` | — |
| POST | `/api/reports` | `category`, `latitude`, `longitude`, `description` (optional), `timestamp` (optional) |

Categories: `harassment, stalking, suspicious_activity, poor_lighting, unsafe_area, other`

### Admin / dashboard 🔒 admin only (for Charini)
| Method | Path | Notes |
|---|---|---|
| GET | `/api/admin/incidents` | Live feed. Query: `kind=sos\|report`, `status=active`, `since=<ISO time>`, `limit` (max 500). Poll every 3-5 seconds with `since` = the newest `received_at` you already have. |
| GET | `/api/admin/hotspots` | Heatmap cells: `latitude, longitude, incident_count, risk_level, peak_hour`. Query: `days=30`, `cell=0.001`, `tz_offset=330` |
| GET | `/api/admin/stats` | Totals by kind, status, category and hour |

### Errors
Always JSON like `{"error": "message"}`. Codes: 400 bad input, 401 not logged in,
403 not allowed, 404 not found, 409 conflict.

---

## Ideas to improve (pick any after the basics work)
- Rate-limit `/api/reports` and `/api/auth/login` to stop spam and guessing (Flask-Limiter).
- Real "safe PIN" check on `/resolve`.
- Push notifications (Firebase) in addition to SMS.
- Escalation: if the first guardian cannot be reached, alert the next.
- Duress PIN that looks like cancel but keeps the alert running.

## Troubleshooting
| Problem | Fix |
|---|---|
| `pip` or `python` not found | Reinstall Python and tick "Add to PATH"; reopen the terminal |
| `No module named flask` | Activate the venv first (`venv\Scripts\activate`) |
| Phone cannot connect | Same Wi-Fi, use laptop IP not `localhost`, allow firewall |
| `401 Missing token` | Add header `Authorization: Bearer <token>` (log in again if expired) |
| `409 already registered` | That phone exists; use Login, or a different number |
| Want a clean database | Stop the server, delete `safeher.db`, run `seed_admin.py` again |
