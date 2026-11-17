import 'package:latlong2/latlong.dart';

/// Central place for values the team may want to change.
class AppConfig {
  /// Design shows "[APP NAME]". Replace once the team picks a name.
  static const appName = 'KAVACH';

  /// Team decision: the countdown before an SOS is sent is 1 minute.
  static const sosCountdownSeconds = 60;

  /// Shake detection (tune these on a real phone).
  /// A "peak" = the acceleration differs from resting gravity by more than this (m/s^2).
  static const shakeThreshold = 12.0;

  /// This many peaks inside [shakeWindow] count as one deliberate shake.
  /// One bump or a dropped phone makes a single peak, so it does not trigger.
  static const shakePeaksNeeded = 3;
  static const shakeWindow = Duration(milliseconds: 1500);

  /// After a countdown closes (cancelled or sent), shaking is ignored for this
  /// long, so the same movement cannot immediately reopen it.
  static const shakeCooldown = Duration(seconds: 5);

  /// Two peaks closer than this count as one (a single jolt rings for a few samples).
  static const shakePeakGap = Duration(milliseconds: 120);

  /// TODO: put your campus coordinates here (do not guess them).
  /// This placeholder only shows an overview of India.
  static const campusCenter = LatLng(20.5937, 78.9629);
  static const campusZoom = 4.5;

  /// Backend address. 10.0.2.2 reaches your laptop from the Android EMULATOR.
  /// For a REAL phone, build with your laptop's Wi-Fi IP, e.g.:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.8:5000
  ///   flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.8:5000
  static const apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'com.example.wsa_app';
}
