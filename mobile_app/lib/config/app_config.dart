import 'package:latlong2/latlong.dart';

/// Central place for values the team may want to change.
class AppConfig {
  /// Design shows "[APP NAME]". Replace once the team picks a name.
  static const appName = 'KAVACH';

  /// Figma shows a 5 second countdown after a shake.
  /// DECISION NEEDED: the original requirement text mentions 1-2 minutes.
  static const sosCountdownSeconds = 5;

  /// TODO: put your campus coordinates here (do not guess them).
  /// This placeholder only shows an overview of India.
  static const campusCenter = LatLng(20.5937, 78.9629);
  static const campusZoom = 4.5;

  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'com.example.wsa_app';
}
