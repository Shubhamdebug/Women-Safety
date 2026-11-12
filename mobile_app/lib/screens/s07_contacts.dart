import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S07 Contacts. Arrow: Add / Edit -> S08.
class S07Contacts extends StatelessWidget {
  const S07Contacts({super.key});

  Future<void> _delete(BuildContext context, Contact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${c.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) AppState.I.deleteContact(c);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final list = AppState.I.contacts;
        return Scaffold(
          appBar: AppBar(title: const Text('Contacts')),
          body: SafeArea(
            child: Column(children: [
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                              'No emergency contacts yet.\nAdd the people who should be alerted.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted, fontSize: 16)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return AppCard(
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name,
                                          style: const TextStyle(
                                              fontSize: 17, fontWeight: FontWeight.w700)),
                                      Text('${c.phone}  |  ${c.relationship}',
                                          style: const TextStyle(color: AppColors.muted)),
                                    ]),
                              ),
                              IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => Navigator.pushNamed(
                                      context, Routes.contactForm, arguments: c)),
                              IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                  onPressed: () => _delete(context, c)),
                            ]),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.contactForm),
                    child: const Text('Add contact')),
              ),
            ]),
          ),
        );
      },
    );
  }
}
