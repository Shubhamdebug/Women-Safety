import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/app_state.dart';

/// S04 SOS Countdown. Arrows: Cancel -> S03, Send now / countdown ends -> S05.
/// NOTE: this timer only runs while the screen is open. The real shake
/// trigger and a screen-off-safe timer need Vignesh's foreground service.
class S04SosCountdown extends StatefulWidget {
  const S04SosCountdown({super.key});
  @override
  State<S04SosCountdown> createState() => _S04State();
}

class _S04State extends State<S04SosCountdown> {
  int _left = AppConfig.sosCountdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _send();
      }
    });
  }

  void _send() {
    _timer?.cancel();
    AppState.I.createEvent('shake');
    Navigator.pushNamedAndRemoveUntil(
        context, Routes.sosStatus, ModalRoute.withName(Routes.home));
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 40),
              const Text('SHAKE DETECTED',
                  style: TextStyle(color: Colors.white70, letterSpacing: 1.6, fontSize: 15)),
              const SizedBox(height: 16),
              const Text('SOS will be sent in',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 48),
              Container(
                width: 210,
                height: 210,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5484D), width: 8),
                ),
                child: Text('$_left',
                    style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 36),
              const Text('Your emergency contacts will receive your location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 17)),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: _send,
                child: const Text('Send now'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: AppColors.ink),
                onPressed: _cancel,
                child: const Text('Cancel'),
              ),
            ]),
          ),
        ),
      );
}
