import 'dart:async';
import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S06 Live Sharing. Arrow: Stop sharing -> S03 Home.
/// Location updates are demo only until GPS is connected (Vignesh).
class S06LiveSharing extends StatefulWidget {
  const S06LiveSharing({super.key});
  @override
  State<S06LiveSharing> createState() => _S06State();
}

class _S06State extends State<S06LiveSharing> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _stop() {
    AppState.I.stopLive();
    Navigator.popUntil(context, ModalRoute.withName(Routes.home));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final since = s.liveSince ?? DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Live sharing'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.teal.withOpacity(0.15)),
              child: const Icon(Icons.my_location, size: 64, color: AppColors.teal),
            ),
            const SizedBox(height: 24),
            Text(s.liveSharing ? 'Sharing your location' : 'Sharing stopped',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(fmtDuration(DateTime.now().difference(since)),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.teal)),
            const SizedBox(height: 16),
            AppCard(
              child: Column(children: [
                StepRow(
                    label: 'Emergency contacts',
                    detail: '${s.contacts.length} saved',
                    state: s.contacts.isNotEmpty ? StepStatus.done : StepStatus.warn),
                const StepRow(
                    label: 'Location updates',
                    detail: 'Demo only - GPS is not connected yet',
                    state: StepStatus.warn),
              ]),
            ),
            const Spacer(),
            FilledButton(onPressed: _stop, child: const Text('Stop sharing')),
          ]),
        ),
      ),
    );
  }
}
