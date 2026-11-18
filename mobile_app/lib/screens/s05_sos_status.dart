import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
      if (!mounted || s.activeEvent != e) return;
      await s.startLive();
      if (!mounted || s.activeEvent != e) return;
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
        final saved = e.savedOnDevice;
        final String savedDetail;
        final StepStatus savedState;
        if (synced) {
          savedDetail = 'The server has it now';
          savedState = StepStatus.done;
        } else if (saved == true) {
          savedDetail = 'Kept even if the app restarts';
          savedState = StepStatus.done;
        } else if (saved == false) {
          savedDetail = 'Could not save on this device';
          savedState = StepStatus.warn;
        } else {
          savedDetail = 'Saving...';
          savedState = StepStatus.pending;
        }
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
                  StepRow(
                      label: 'Saved on this device',
                      detail: savedDetail,
                      state: savedState),
                  StepRow(
                      label: 'Location',
                      detail: AppState.I.locationDetail,
                      state: e.location != null ? StepStatus.done : StepStatus.warn),
                  StepRow(
                    label: 'Sent to server',
                    detail: synced
                        ? 'Received by server'
                        : _sending
                            ? 'Sending...'
                            : AppState.I.lastSendError ?? 'Not sent yet',
                    state: synced
                        ? StepStatus.done
                        : _sending ? StepStatus.pending : StepStatus.warn,
                  ),
                  StepRow(
                      label: 'Contacts alerted',
                      detail: e.alertDetail.isNotEmpty ? e.alertDetail : 'Not sent yet',
                      state: e.contactsStatus == 'handed_off'
                          ? StepStatus.done
                          : StepStatus.warn),
                ]),
              ),
              if (!synced && !_sending) ...[
                if (e.location == null)
                  TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text('Open location permission settings')),
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
