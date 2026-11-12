import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S03 Home. Arrows: tap SOS -> S05, shake -> S04, Start -> S06,
/// Contacts S07, History S10, Safety Map S11, Report S12,
/// Profile S09, change permissions S13.
class S03Home extends StatelessWidget {
  const S03Home({super.key});

  Widget _circle(double size, Color c, {Widget? child}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        return Scaffold(
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Row(children: [
                const Expanded(
                  child: Text('Home', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, Routes.profile),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.person_outline),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Text.rich(TextSpan(
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      children: [
                        const TextSpan(text: 'Shake protection: '),
                        TextSpan(
                          text: s.shakeProtection ? 'ON' : 'OFF',
                          style: TextStyle(
                              color: s.shakeProtection ? AppColors.teal : AppColors.muted),
                        ),
                      ],
                    )),
                  ),
                  Switch(
                    value: s.shakeProtection,
                    onChanged: (v) {
                      s.shakeProtection = v;
                      s.changed();
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Center(
                child: Semantics(
                  button: true,
                  label: 'SOS emergency button',
                  child: GestureDetector(
                    onTap: () {
                      s.createEvent('tap');
                      Navigator.pushNamed(context, Routes.sosStatus);
                    },
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(alignment: Alignment.center, children: [
                        _circle(260, AppColors.red.withOpacity(0.08)),
                        _circle(222, AppColors.red.withOpacity(0.15)),
                        _circle(196, AppColors.red,
                            child: const Text('SOS',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w800))),
                      ]),
                    ),
                  ),
                ),
              ),
              const Text('Tap to send an alert. You can also shake your phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.muted)),
              if (kDebugMode)
                TextButton(
                  onPressed: s.shakeProtection
                      ? () => Navigator.pushNamed(context, Routes.sosCountdown)
                      : null,
                  child: const Text('Demo: simulate shake'),
                ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Live location sharing',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(s.liveSharing ? 'On since ${fmtTime(s.liveSince!)}' : 'Off',
                          style: const TextStyle(color: AppColors.muted, fontSize: 16)),
                    ]),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      minimumSize: const Size(96, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (s.liveSharing) {
                        s.stopLive();
                      } else {
                        s.startLive();
                        Navigator.pushNamed(context, Routes.liveSharing);
                      }
                    },
                    child: Text(s.liveSharing ? 'Stop' : 'Start'),
                  ),
                ]),
              ),
              const Row(children: [
                Expanded(child: _NavCard('Contacts', Routes.contacts)),
                SizedBox(width: 12),
                Expanded(child: _NavCard('History', Routes.history)),
              ]),
              const Row(children: [
                Expanded(child: _NavCard('Safety Map', Routes.map)),
                SizedBox(width: 12),
                Expanded(child: _NavCard('Report', Routes.report)),
              ]),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.permissions),
                  child: const Text('Permissions & setup'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _NavCard extends StatelessWidget {
  final String label, route;
  const _NavCard(this.label, this.route);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
      );
}
