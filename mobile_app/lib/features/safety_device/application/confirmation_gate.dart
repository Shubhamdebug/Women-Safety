import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/safety_config.dart';

/// Owns no delivery API: sensor activity can only enter the confirmation flow.
class ConfirmationGate {
  ConfirmationGate(this.bridge, this.config) {
    config.validate();
  }
  final ConfirmationBridge bridge;
  final SafetyConfig config;
  bool _pending = false;
  bool get isPending => _pending;

  Future<bool> request(SafetyTrigger trigger) async {
    if (_pending) return false;
    _pending = true;
    try {
      return await bridge.requestConfirmation(
        trigger,
        config.confirmationDuration,
      );
    } finally {
      _pending = false;
    }
  }
}
