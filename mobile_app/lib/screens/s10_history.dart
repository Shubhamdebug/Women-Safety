import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S10 Incident History: your own SOS events only.
/// Anonymous reports are NOT listed here on purpose, because they are not
/// linked to any account.
class S10History extends StatelessWidget {
  const S10History({super.key});

  Color _color(String s) => s == 'active'
      ? AppColors.red
      : s == 'resolved' ? AppColors.teal : AppColors.orange;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final list = AppState.I.events;
        return Scaffold(
          appBar: AppBar(title: const Text('Incident History')),
          body: SafeArea(
            child: list.isEmpty
                ? const Center(
                    child: Text('No SOS events yet.', style: TextStyle(color: AppColors.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final e = list[i];
                      return AppCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text('SOS by ${e.trigger}',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            ),
                            StatusChip(e.status, _color(e.status)),
                          ]),
                          const SizedBox(height: 4),
                          Text(fmtDateTime(e.time)),
                          const SizedBox(height: 4),
                          Text(
                              'Server: ${e.syncStatus}  |  Contacts: ${e.contactsStatus.replaceAll('_', ' ')}',
                              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                        ]),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
