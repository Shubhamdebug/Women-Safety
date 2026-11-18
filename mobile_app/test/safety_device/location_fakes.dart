import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:wsa_app/features/safety_device/domain/models.dart' as device;
import 'package:wsa_app/features/safety_device/domain/ports.dart';

Position positionAt(DateTime time, {double accuracy = 8}) => Position(
  latitude: 12.5,
  longitude: 77.5,
  timestamp: time,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracy = LocationAccuracyStatus.precise;
  bool enabled = true;
  int permissionRequests = 0;
  int fixRequests = 0;
  Future<Position> Function()? fix;
  Position? cached;
  LocationSettings? streamSettings;
  final positions = StreamController<Position>.broadcast(sync: true);
  final services = StreamController<ServiceStatus>.broadcast(sync: true);

  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = requestedPermission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracy;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fixRequests++;
    return fix == null ? positionAt(DateTime.now()) : await fix!();
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => cached;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamSettings = locationSettings;
    return positions.stream;
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() => services.stream;

  Future<void> close() async {
    await positions.close();
    await services.close();
  }
}

class FakeTrackingController implements ForegroundTrackingController {
  final stateEvents = StreamController<TrackingState>.broadcast(sync: true);
  final locationEvents = StreamController<device.LocationSnapshot>.broadcast(
    sync: true,
  );
  int starts = 0;
  int stops = 0;
  @override
  Stream<TrackingState> get states => stateEvents.stream;
  @override
  Stream<device.LocationSnapshot> get locations => locationEvents.stream;
  @override
  Future<void> startTracking(String sessionId) async {
    starts++;
    stateEvents.add(TrackingState.starting);
  }

  @override
  Future<void> stopTracking() async {
    stops++;
    stateEvents.add(TrackingState.stopped);
  }

  Future<void> close() async {
    await stateEvents.close();
    await locationEvents.close();
  }
}

device.LocationSnapshot snapshotAt(DateTime time) => device.LocationSnapshot(
  latitude: 12.5,
  longitude: 77.5,
  accuracyMeters: 8,
  capturedAt: time,
  source: device.LocationSource.current,
);

Future<void> flushAsync() => Future<void>.delayed(Duration.zero);
