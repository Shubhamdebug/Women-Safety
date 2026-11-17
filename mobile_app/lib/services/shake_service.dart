import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../config/app_config.dart';

/// Detects a deliberate shake with the phone's accelerometer.
/// It only listens while the app is open on screen: when the app goes to the
/// background it stops, so a countdown can never start where nobody sees it.
/// (Working with the screen off needs Vignesh's foreground service.)
class ShakeService with WidgetsBindingObserver {
  ShakeService._();
  static final ShakeService I = ShakeService._();

  static const _gravity = 9.80665; // m/s^2, what the sensor reads at rest

  void Function()? _onShake;
  void Function(bool available)? _onAvailability;
  StreamSubscription<AccelerometerEvent>? _sub;
  final List<DateTime> _peaks = [];
  DateTime? _lastPeak;
  bool _started = false;
  bool _gotEvent = false;

  /// [onShake] is called once per detected shake.
  /// [onAvailability] is told false if this device has no usable accelerometer
  /// (for example Windows or Chrome), and true once real readings arrive.
  void start({required void Function() onShake, void Function(bool available)? onAvailability}) {
    if (_started) return;
    _started = true;
    _onShake = onShake;
    _onAvailability = onAvailability;
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  void _listen() {
    if (_sub != null) return;
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        _onEvent,
        onError: (Object _) {
          _stopListening();
          _onAvailability?.call(false);
        },
        cancelOnError: true,
      );
    } catch (_) {
      _sub = null;
      _onAvailability?.call(false);
    }
  }

  void _stopListening() {
    _sub?.cancel();
    _sub = null;
    _peaks.clear();
    _lastPeak = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _listen();
    } else {
      _stopListening();
    }
  }

  void _onEvent(AccelerometerEvent e) {
    if (!_gotEvent) {
      _gotEvent = true;
      _onAvailability?.call(true);
    }
    // How far the total acceleration is from plain gravity. About 0 when the
    // phone is still or moving gently, large when it is shaken hard.
    final deviation = (sqrt(e.x * e.x + e.y * e.y + e.z * e.z) - _gravity).abs();
    if (deviation < AppConfig.shakeThreshold) return;

    final now = DateTime.now();
    final last = _lastPeak;
    if (last != null && now.difference(last) < AppConfig.shakePeakGap) return;
    _lastPeak = now;

    _peaks.add(now);
    _peaks.removeWhere((t) => now.difference(t) > AppConfig.shakeWindow);
    if (_peaks.length >= AppConfig.shakePeaksNeeded) {
      _peaks.clear();
      _onShake?.call();
    }
  }
}
