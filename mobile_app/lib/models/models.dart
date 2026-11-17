class Account {
  final String name, phone, email, password; // password: mock only, backend must hash
  Account(this.name, this.phone, this.email, this.password);
}

class Contact {
  final String id;
  String name, phone, relationship;
  Contact({required this.id, required this.name, required this.phone, required this.relationship});
}

/// status: active | resolved | cancelled
/// syncStatus: pending | received   (backend received it)
/// contactsStatus: not_notified | handed_off | confirmed
/// Saving locally, reaching the server and alerting contacts are separate outcomes.
class EmergencyEvent {
  final String id;
  final DateTime time;
  final String trigger; // button | shake (must match backend)
  String status;
  String syncStatus;
  String contactsStatus;
  String alertDetail; // e.g. "2 of 2 contacts alerted"
  /// null = still saving, true = written to encrypted storage, false = saving failed.
  bool? savedOnDevice;
  EmergencyEvent({
    required this.id,
    required this.time,
    required this.trigger,
    this.status = 'active',
    this.syncStatus = 'pending',
    this.contactsStatus = 'not_notified',
    this.alertDetail = '',
    this.savedOnDevice,
  });

  /// Only what is needed to resend an unsent SOS after a restart.
  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toUtc().toIso8601String(),
        'trigger': trigger,
      };

  /// Returns null if the saved data is damaged (then it is simply dropped).
  static EmergencyEvent? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final trigger = j['trigger'];
    final t = DateTime.tryParse('${j['time']}');
    if (id is! String || trigger is! String || t == null) return null;
    return EmergencyEvent(
        id: id, time: t.toLocal(), trigger: trigger, savedOnDevice: true);
  }
}

/// Deliberately has NO user fields: reports stay anonymous.
class AnonymousReport {
  final String category, locationText, description;
  final double? lat, lng;
  final DateTime incidentTime, createdAt;
  AnonymousReport({
    required this.category,
    required this.locationText,
    required this.description,
    required this.incidentTime,
    required this.createdAt,
    this.lat,
    this.lng,
  });
}
