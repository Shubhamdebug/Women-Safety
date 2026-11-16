import 'package:latlong2/latlong.dart';

/// Central place for values the team may want to change.
class AppConfig {
  /// Design shows "[APP NAME]". Replace once the team picks a name.
  static const appName = 'KAVACH';

  /// Team decision: the countdown before an SOS is sent is 1 minute.
  static const sosCountdownSeconds = 60;

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
