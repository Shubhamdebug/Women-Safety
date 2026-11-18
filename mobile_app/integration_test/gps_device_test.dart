import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wsa_app/features/safety_device/data/android_location_repository.dart';
import 'package:wsa_app/features/safety_device/domain/models.dart';
import 'package:wsa_app/features/safety_device/domain/safety_config.dart';

/// Runs GPS acquisition directly. It does not authenticate or send an SOS.
/// Choose the case with --dart-define=GPS_TEST_CASE=allowed (or approximate,
/// denied, permanentlyDenied, disabled, timeout) and set phone permissions/GPS
/// to that condition before starting. Never log coordinates.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const scenario = String.fromEnvironment(
    'GPS_TEST_CASE',
    defaultValue: 'allowed',
  );
  testWidgets('Real Android GPS: $scenario', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Text(
            'KAVACH GPS check. Respond to the phone permission prompt.',
          ),
        ),
      ),
    );
    const config = scenario == 'timeout'
        ? SafetyConfig(
            locationTimeout: Duration(microseconds: 1),
            maximumCachedLocationAge: Duration(microseconds: 1),
          )
        : SafetyConfig(locationTimeout: Duration(seconds: 30));
    final result = await AndroidLocationRepository(config: config).capture();
    if (scenario == 'allowed' || scenario == 'approximate') {
      expect(
        result.snapshot,
        isNotNull,
        reason: 'GPS result: ${result.failure?.name}',
      );
      expect(result.snapshot!.capturedAtUtc.isUtc, isTrue);
      if (scenario == 'approximate') {
        expect(result.snapshot!.precision, LocationPrecision.approximate);
      }
    } else {
      final failure = LocationFailure.values.byName(scenario);
      expect(result.failure, failure);
      expect(result.snapshot, isNull);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
