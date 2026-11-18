import '../../../models/models.dart' as app;
import '../domain/models.dart' as device;

/// Explicit wire mapping for backend/routes/sos.py. Local toJson is storage-only.
class SosPayloadAdapter {
  static const acceptedTriggers = {
    'button',
    'shake',
    'low_battery',
    'timer',
    'voice',
    'other',
  };

  static Map<String, dynamic> create(app.EmergencyEvent event) {
    final trigger = event.trigger == 'manual' ? 'button' : event.trigger;
    final location = event.location;
    return {
      'id': event.id,
      'trigger': acceptedTriggers.contains(trigger) ? trigger : 'other',
      'timestamp': event.time.toUtc().toIso8601String(),
      if (location != null) ...{
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
    };
  }

  static Map<String, dynamic> ping(device.LocationSnapshot location) => {
    'latitude': location.latitude,
    'longitude': location.longitude,
    'timestamp': location.capturedAtUtc.toIso8601String(),
  };
}
