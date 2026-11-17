/// Starting values for device testing, not measured reliability guarantees.
///
/// Team decision: the confirmation (SOS countdown) is 60 seconds. The live
/// countdown and shake detection currently run from AppConfig
/// (lib/config/app_config.dart); the shake values below are not used yet.
class SafetyConfig {
  const SafetyConfig({
    this.confirmationDuration = const Duration(seconds: 60),
    this.locationTimeout = const Duration(seconds: 12),
    this.maximumCachedLocationAge = const Duration(minutes: 2),
    this.trackingInterval = const Duration(seconds: 30),
    this.minimumLocationDistanceMeters = 20,
    this.shakeThresholdMetersPerSecondSquared = 18,
    this.shakeRequiredPeaks = 3,
    this.shakeWindow = const Duration(seconds: 2),
    this.shakeDebounce = const Duration(milliseconds: 250),
    this.shakeCooldown = const Duration(seconds: 10),
    this.batteryPreAlertThreshold = 15,
    this.batteryRearmThreshold = 20,
    this.initialRetryDelay = const Duration(seconds: 5),
    this.maximumRetryDelay = const Duration(minutes: 5),
    this.maximumAutomaticAttempts = 8,
  });

  final Duration confirmationDuration;
  final Duration locationTimeout;
  final Duration maximumCachedLocationAge;
  final Duration trackingInterval;
  final double minimumLocationDistanceMeters;
  final double shakeThresholdMetersPerSecondSquared;
  final int shakeRequiredPeaks;
  final Duration shakeWindow;
  final Duration shakeDebounce;
  final Duration shakeCooldown;
  final int batteryPreAlertThreshold;
  final int batteryRearmThreshold;
  final Duration initialRetryDelay;
  final Duration maximumRetryDelay;
  final int maximumAutomaticAttempts;

  void validate() {
    final durations = [
      confirmationDuration,
      locationTimeout,
      maximumCachedLocationAge,
      trackingInterval,
      shakeWindow,
      shakeDebounce,
      shakeCooldown,
      initialRetryDelay,
      maximumRetryDelay,
    ];
    if (durations.any((d) => d <= Duration.zero) ||
        !minimumLocationDistanceMeters.isFinite ||
        minimumLocationDistanceMeters < 0 ||
        !shakeThresholdMetersPerSecondSquared.isFinite ||
        shakeThresholdMetersPerSecondSquared <= 0 ||
        shakeRequiredPeaks < 2 ||
        maximumAutomaticAttempts < 1 ||
        batteryPreAlertThreshold < 0 ||
        batteryRearmThreshold > 100 ||
        batteryPreAlertThreshold >= batteryRearmThreshold ||
        initialRetryDelay > maximumRetryDelay ||
        shakeDebounce > shakeWindow) {
      throw ArgumentError('Invalid safety configuration');
    }
  }
}
