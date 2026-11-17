import 'models.dart';

abstract interface class Clock {
  DateTime nowUtc();
}

abstract interface class EventIdGenerator {
  String next();
}

abstract interface class LocationRepository {
  Future<LocationResult> capture();
}

/// BLOCKER: reconcile the implementation with Rishi's schema/migrations.
abstract interface class EmergencyQueueRepository {
  /// Must durably insert with a unique eventId, or throw on persistence failure.
  Future<void> insert(EmergencyEvent event);
  Future<List<EmergencyEvent>> pendingForOwner(String ownerId);
}

class ServerAcknowledgment {
  const ServerAcknowledgment({required this.eventId});
  final String eventId;
}

/// BLOCKER: Tanisha must supply endpoint, authentication and ack semantics.
abstract interface class EmergencyApi {
  Future<ServerAcknowledgment> send(EmergencyEvent event);
}

abstract interface class SmsFallbackService {
  Future<bool> isAvailable();

  /// Must be invoked from a confirmed emergency and explicit user action.
  /// Opening a composer only reports userActionRequired, never delivery.
  Future<SmsState> openComposer(EmergencyEvent event, List<String> recipients);
}

/// Shubham owns the screen, countdown, cancellation and confirmation policy.
abstract interface class ConfirmationBridge {
  Future<bool> requestConfirmation(SafetyTrigger trigger, Duration duration);
}

enum TrackingState { stopped, starting, active, failed }

abstract interface class ForegroundTrackingController {
  Stream<TrackingState> get states;
  Stream<LocationSnapshot> get locations;
  Future<void> startTracking(String sessionId);
  Future<void> stopTracking();
}
