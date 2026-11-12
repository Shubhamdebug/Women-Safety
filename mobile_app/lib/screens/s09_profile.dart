import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S09 Profile. Arrow: log out -> S01 Login.
class S09Profile extends StatefulWidget {
  const S09Profile({super.key});
  @override
  State<S09Profile> createState() => _S09State();
}

class _S09State extends State<S09Profile> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: AppState.I.user?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: AppState.I.user?.phone ?? '');
  late final TextEditingController _email =
      TextEditingController(text: AppState.I.user?.email ?? '');

  @override
  void dispose() {
    for (final c in [_name, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    AppState.I.updateProfile(_name.text.trim(), _phone.text.trim());
    snack(context, 'Profile saved on this device');
  }

  void _logout() {
    AppState.I.logout();
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: SafeArea(
          child: Form(
            key: _key,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              AppField(label: 'Full name', controller: _name,
                  validator: (v) => Validators.required(v, 'Name')),
              AppField(label: 'Phone number', controller: _phone,
                  keyboard: TextInputType.phone, validator: Validators.phone),
              AppField(label: 'Email', controller: _email, enabled: false),
              FilledButton(onPressed: _save, child: const Text('Save changes')),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permissions & setup',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, Routes.permissions),
              ),
              if (kDebugMode)
                ListenableBuilder(
                  listenable: AppState.I,
                  builder: (context, _) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Demo: device is online'),
                    subtitle: const Text('Turn off to test the offline SOS path'),
                    value: AppState.I.online,
                    onChanged: (v) {
                      AppState.I.online = v;
                      AppState.I.changed();
                    },
                  ),
                ),
              const Divider(height: 32),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red, width: 1.2)),
                onPressed: _logout,
                child: const Text('Log out'),
              ),
            ]),
          ),
        ),
      );
}
