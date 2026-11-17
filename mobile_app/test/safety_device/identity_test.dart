import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_app/features/safety_device/data/runtime_identity.dart';

void main() {
  test('event IDs have UUID v4 version/variant and do not repeat in a sample', () {
    final generator = SecureEventIdGenerator();
    final ids = List.generate(1000, (_) => generator.next());
    final format = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(ids.every(format.hasMatch), isTrue);
    expect(ids.toSet().length, ids.length);
    expect(SystemClock().nowUtc().isUtc, isTrue);
  });
}
