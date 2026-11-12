import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S05 SOS Status. Arrow: online success -> S06 Live Sharing.
/// Honest checklist: saved locally, reached server and alerted contacts
/// are shown as separate outcomes.
class S05SosStatus extends StatefulWidget {
  const S05SosStatus({super.key});
  @override
  State<S05SosStatus> createState() => _S05State();
}

class _S05State extends State<S05SosStatus> {
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  Future<void> _send() async {
    final s = AppState.I;
    final e = s.activeEvent;
    if (e == null || _sending) return;
    setState(() => _sending = true);
    final ok = await s.sendEvent(e);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || s.activeEvent == null) return;
      s.startLive();
      Navigator.pushReplacementNamed(context, Routes.liveSharing);
    }
  }

  void _cancel() {
    final e = AppState.I.activeEvent;
    if (e != null) AppState.I.cancelEvent(e);
    Navigator.popUntil(context, ModalRoute.withName(Routes.home));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final e = AppState.I.activeEvent;
        if (e == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('SOS status')),
            body: const Center(child: Text('No active SOS.')),
          );
        }
        final synced = e.syncStatus == 'received';
        return Scaffold(
          appBar: AppBar(title: const Text('SOS status'), automaticallyImplyLeading: false),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: AppColors.red, borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  const Text('SOS ACTIVE',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('Triggered by ${e.trigger} at ${fmtTime(e.time)}',
                      style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(children: [
                  StepRow(
                      label: 'Event created',
                      detail: '#${e.id.substring(e.id.length - 6)}',
                      state: StepStatus.done),
                  const StepRow(
                      label: 'Saved on this device',
                      detail: 'Kept even if the app restarts',
                      state: StepStatus.done),
                  StepRow(
                    label: 'Sent to server',
                    detail: synced
                        ? 'Received (demo server)'
                        : _sending
                            ? 'Sending...'
                            : 'Offline - will sync when connected',
                    state: synced
                        ? StepStatus.done
                        : _sending ? StepStatus.pending : StepStatus.warn,
                  ),
                  const StepRow(
                      label: 'Contacts alerted',
                      detail: 'Not sent yet - SMS / push is not connected',
                      state: StepStatus.warn),
                ]),
              ),
              if (!synced && !_sending) ...[
                FilledButton(onPressed: _send, child: const Text('Retry sending')),
                const SizedBox(height: 12),
              ],
              OutlinedButton(onPressed: _cancel, child: const Text("I'm safe - cancel SOS")),
            ]),
          ),
        );
      },
    );
  }
}
