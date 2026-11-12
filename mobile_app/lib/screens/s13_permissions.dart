import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S13 Permissions & Setup. Shown on first login, and from Home / Profile.
/// Arrow: done -> S03 Home.
/// The switches are placeholders. Vignesh replaces them with real OS
/// permission requests (for example the permission_handler package).
class S13Permissions extends StatelessWidget {
  const S13Permissions({super.key});

  static const reasons = {
    'Location': 'Share your position with contacts during an SOS or live sharing.',
    'Notifications': 'Show SOS and live sharing status.',
    'Motion sensors': 'Detect a shake to start the SOS countdown.',
    'SMS': 'Send an alert from your phone when there is no internet (Android).',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Permissions & setup'),
            automaticallyImplyLeading: s.setupDone,
          ),
          body: SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                        'We only ask for what each safety feature needs. Demo mode: these switches do not change real phone permissions yet.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                  ...s.permissions.keys.map((k) => AppCard(
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(k,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              Text(reasons[k] ?? '',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
                            ]),
                          ),
                          Switch(
                            value: s.permissions[k]!,
                            onChanged: (v) {
                              s.permissions[k] = v;
                              s.changed();
                            },
                          ),
                        ]),
                      )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  onPressed: () {
                    s.setupDone = true;
                    Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
                  },
                  child: const Text('Done'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
