# Vignesh: T19 GPS and T20 foreground tracking

Prepared 17 November 2026 against team `main` commit `1222cbc`, on branch
`vignesh/gps-foreground-tracking`. This replaces the earlier standalone-foundation
handoff. Apply these changes inside the team's `mobile_app` (`wsa_app`).

## Implemented

- `AndroidLocationRepository`: foreground permission request, denied/permanently
  denied, GPS disabled, bounded fix timeout, approximate-only and precise fixes.
  A fresh cached fix can be used after acquisition failure; its age, accuracy,
  source and original failure are retained. Stale/future fixes are rejected.
- Explicit SOS payload adapter, prefixed domain imports, backend trigger allowlist.
  The campus-center placeholder is removed from SOS submissions. No fix means
  coordinates are omitted and the failure is retained on the local event.
- Existing encrypted pending-SOS storage is reused, including the original UUID.
  The initial save is awaited before GPS/network work. Concurrent sends share one
  request; cancel/logout during GPS prevents a late send. Only a matching incident
  acknowledgment marks the event received.
- Foreground location service begins after an acknowledged SOS while the app is
  visible. It requests a visible ongoing notification and receives positions about
  every 30 seconds. Pings use `/api/sos/<same UUID>/location`, without overlapping
  requests. The UI distinguishes tracking from server acknowledgment.
- Cancel, resolve, logout, GPS/service failure and a server closed/unauthorized
  response stop the local session. Failed network pings retry with the next eligible
  fix; location-ping persistence is outside version 1.
- Android coarse/fine location, foreground service/location, notification and wake
  lock permissions. No background-location permission: the service must start
  while the app is visible. Continuing after backgrounding requires phone testing.
- Small integration edits to existing SOS/home/live-sharing screens show actual
  location/tracking status and expose settings/retry actions.

The 60-second confirmation, existing shake implementation, app entrypoint and
encrypted pending-SOS mechanism are retained. No standalone pubspec, main.dart or
Android folder was copied. SQLite, battery, camera, voice, SMS fallback and
screen-off shake are not added.

## Backend dependency: GPS-less SOS is not accepted yet

At this base commit, `backend/routes/sos.py:create_sos` returns HTTP 400 when either
coordinate is absent, before the UUID duplicate check. The mobile app attempts the
GPS-less request and keeps a rejected event pending with its original UUID. It
does not invent coordinates or claim server acceptance.

Tanisha/Rishi need to agree on an optional-coordinate SOS contract, update validation
and storage accordingly, and ensure alert text/dashboard/map handling can represent
an incident whose location is unknown. Location pings should still require valid
coordinates. Check duplicate requests with missing coordinates too. These backend,
database and dashboard changes are not included in Vignesh's mobile changes.

Until that work lands, the full requirement "SOS reaches the server despite GPS
failure" is **blocked**, even though the mobile failure path is implemented.

## Toolchain

Actual Flutter version output on this computer:

```text
Flutter 3.50.0 • channel stable • https://github.com/flutter/flutter.git
Framework • revision ab2912035e (8 days ago) • 2026-11-09 08:50:21 -0800
Engine • hash bf601093ad255aaf5c6d0fc5c4f9acfa60943b2a (revision 371f77202a) (7 days ago) • 2026-11-09 15:57:36.000Z
Tools • Dart 3.14.0 • DevTools 2.61.0
```

Team SDK constraint `^3.13.7` permits Dart 3.14.0 and is unchanged. Resolved GPS
dependency: geolocator 14.0.2; notifications: permission_handler 13.0.2.
The lockfile is included. Validation here uses Flutter 3.50.0/Dart 3.14.0; a separate
run with Dart 3.13.7 has not been performed.

## Verification

| Check | Actual result |
|---|---|
| Flutter unit tests | 34 passed |
| Static analysis | 0 errors, 0 warnings; 26 existing informational diagnostics in team UI/docs |
| Android debug compilation | Not completed: dependency downloads stalled; follow-up build check blocked by approval-review usage limit |
| Phone connected | OPPO CPH2625, Android 16; USB debugging authorized |
| GPS allowed / denied / permanent denial / off / approximate / timeout on phone | Not run yet |
| Foreground notification, screen-off continuation, cancel/resolve on phone | Not run yet |
| Live backend/dashboard/SMS | Not run; GPS-less backend contract is blocked as described above |

The automated suite covers all six GPS outcomes, fresh/stale cache, cancellation,
logout, concurrent retries, acknowledgment validation, notification settings,
30-second throttling, service failure and late responses. Platform services,
HTTP responses and secure storage are mocked in these tests. They do not prove
real Android persistence or live server delivery.

Normal commands from `mobile_app`:

```sh
flutter --version
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
flutter test integration_test/gps_device_test.dart -d <phone-id> --no-pub --dart-define=GPS_TEST_CASE=allowed
```

This Windows machine ran Flutter's own Dart entrypoint because its first-run batch
launcher stalled. Android builds use `--no-pub` after successful dependency
resolution to avoid the unrelated Windows-desktop plugin symlink setup. This is
a local tooling workaround, not a change to the team's app.

## Phone rehearsal

`integration_test/gps_device_test.dart` reads location directly. It has no login,
network submission or SOS creation, and does not print coordinates. Set the phone
state before running each case with `GPS_TEST_CASE`:

| Value | Setup / expected result |
|---|---|
| `allowed` | Location on; precise access allowed; valid fresh fix |
| `denied` | Decline the permission prompt; `denied` with no fix |
| `permanentlyDenied` | Block repeated requests/app permission; `permanentlyDenied` |
| `disabled` | Permission allowed, phone Location off; `disabled` |
| `approximate` | Approximate access only, phone Location on; fix marked approximate |
| `timeout` | Permission allowed, Location on; deliberately tiny test deadline/cache age; `timeout` |

The timeout test injects a short deadline; it is not evidence of a naturally occurring
GPS timeout. Record date, model/Android version, outcome and observed issue for every
case. Do not commit coordinates, account tokens or personal contact information.

For T20, use a team-approved test backend/account with simulated notifications:
confirm a 60-second SOS, verify the server sees the real fix, inspect the ongoing
notification, observe several roughly 30-second pings, lock the phone, then cancel
and resolve in separate runs. Verify the notification disappears and no further
pings arrive. Also test denied notifications, GPS switched off, network loss and
recovery, and logout. Android/OEM scheduling can delay pings; app force-stop and
phone restart are not automatic tracking recovery in this version.

## Final handoff status

The code and 34 passing automated tests are ready for source review. T19/T20 are
not yet accepted on a real phone. The OPPO phone was connected, but no GPS device
case or foreground notification check completed; no APK is included.

The exact Gradle 9.3.1 download timed out after 180 seconds with only 5.5 MB of
234.9 MB downloaded. Temporary attempts using cached Gradle 9.5.0, AGP 9.1.1 and
Kotlin 2.4.10 still needed downloads. Those attempts were stopped, and both team
build configuration files were restored exactly from the base commit. The next
cache-only diagnosis was not executed because automatic approval review hit an
account usage limit. This was a review-service failure, not an unsafe-action ruling.

No commit was pushed, no fork was created, and no pull request was opened. The ZIP
provides the changes and a patch for Shubham to review/apply on the team repository.
The local branch is `vignesh/gps-foreground-tracking`.

Stopping tracking prevents new requests; a request already in flight can still
finish on the server. Its late response cannot restart the local session.
