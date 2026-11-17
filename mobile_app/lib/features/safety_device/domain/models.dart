enum LocationSource { current, cached }

enum LocationFailure {
  denied,
  permanentlyDenied,
  disabled,
  timeout,
  unavailable,
}

enum TriggerType { manual, shake, voice }

enum EventKind { sos, batteryPreAlert }

enum ServerSyncState {
  pending,
  syncing,
  acknowledged,
  retryableFailure,
  permanentFailure,
}

enum SmsState { notAttempted, userActionRequired, requested, failed, unknown }

class LocationSnapshot {
  LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required DateTime capturedAt,
    required this.source,
  }) : capturedAtUtc = capturedAt.toUtc() {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !accuracyMeters.isFinite ||
        accuracyMeters < 0) {
      throw ArgumentError('Invalid location measurement');
    }
  }
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAtUtc;
  final LocationSource source;

  bool isFreshAt(DateTime now, Duration maximumAge) {
    final age = now.toUtc().difference(capturedAtUtc);
    return age >= Duration.zero && age <= maximumAge;
  }

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'capturedAtUtc': capturedAtUtc.toIso8601String(),
    'source': source.name,
  };

  factory LocationSnapshot.fromJson(Map<String, dynamic> json) =>
      LocationSnapshot(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
        capturedAt: DateTime.parse(json['capturedAtUtc'] as String),
        source: LocationSource.values.byName(json['source'] as String),
      );
}

class LocationResult {
  const LocationResult({this.snapshot, this.failure});
  final LocationSnapshot? snapshot;

  /// A fallback can retain the reason that a current fix was unavailable.
  final LocationFailure? failure;
}

/// Local domain format only. Tanisha's wire format is not yet agreed.
class EmergencyEvent {
  EmergencyEvent({
    required this.eventId,
    required this.ownerId,
    required DateTime createdAt,
    required this.kind,
    this.trigger,
    this.location,
    this.locationFailure,
    this.batteryPercent,
  }) : createdAtUtc = createdAt.toUtc() {
    if (eventId.isEmpty ||
        ownerId.isEmpty ||
        (kind == EventKind.sos && trigger == null) ||
        (kind == EventKind.batteryPreAlert && trigger != null) ||
        (batteryPercent != null &&
            (batteryPercent! < 0 || batteryPercent! > 100))) {
      throw ArgumentError('Invalid emergency event');
    }
  }
  final String eventId;
  final String ownerId;
  final DateTime createdAtUtc;
  final EventKind kind;
  final TriggerType? trigger;
  final LocationSnapshot? location;
  final LocationFailure? locationFailure;
  final int? batteryPercent;
  bool get isEmergency => kind == EventKind.sos;

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'ownerId': ownerId,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'kind': kind.name,
    'trigger': trigger?.name,
    'location': location?.toJson(),
    'locationFailure': locationFailure?.name,
    'batteryPercent': batteryPercent,
  };

  factory EmergencyEvent.fromJson(Map<String, dynamic> json) => EmergencyEvent(
    eventId: json['eventId'] as String,
    ownerId: json['ownerId'] as String,
    createdAt: DateTime.parse(json['createdAtUtc'] as String),
    kind: EventKind.values.byName(json['kind'] as String),
    trigger: json['trigger'] == null
        ? null
        : TriggerType.values.byName(json['trigger'] as String),
    location: json['location'] == null
        ? null
        : LocationSnapshot.fromJson(json['location'] as Map<String, dynamic>),
    locationFailure: json['locationFailure'] == null
        ? null
        : LocationFailure.values.byName(json['locationFailure'] as String),
    batteryPercent: json['batteryPercent'] as int?,
  );
}

class SafetyTrigger {
  SafetyTrigger({
    required this.id,
    required this.type,
    required DateTime detectedAt,
  }) : detectedAtUtc = detectedAt.toUtc() {
    if (id.isEmpty || type == TriggerType.manual) {
      throw ArgumentError('Device triggers require an ID and shake/voice type');
    }
  }
  final String id;
  final TriggerType type;
  final DateTime detectedAtUtc;
}
