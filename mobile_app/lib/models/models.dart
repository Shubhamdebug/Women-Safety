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
  final String trigger; // tap | shake
  String status;
  String syncStatus;
  String contactsStatus;
  EmergencyEvent({
    required this.id,
    required this.time,
    required this.trigger,
    this.status = 'active',
    this.syncStatus = 'pending',
    this.contactsStatus = 'not_notified',
  });
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
