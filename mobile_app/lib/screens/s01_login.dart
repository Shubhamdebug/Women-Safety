import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S01 Login. Arrows: -> S02 Register, S03 Home (login OK),
/// S13 Permissions (first login), S11 Safety Map and S12 Report (no login).
class S01Login extends StatefulWidget {
  const S01Login({super.key});
  @override
  State<S01Login> createState() => _S01State();
}

class _S01State extends State<S01Login> {
  final _key = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _login() {
    if (!_key.currentState!.validate()) return;
    // TODO(Tanisha's API): POST /api/auth/login, keep the token securely.
    final err = AppState.I.login(_id.text, _pass.text);
    if (err != null) return snack(context, err);
    final next = AppState.I.setupDone ? Routes.home : Routes.permissions;
    Navigator.pushNamedAndRemoveUntil(context, next, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(children: [
              Expanded(
                child: Form(
                  key: _key,
                  child: ListView(children: [
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.shield_outlined, color: AppColors.red, size: 56),
                    ),
                    const SizedBox(height: 16),
                    const Text(AppConfig.appName,
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Log in to your safety account.',
                        style: TextStyle(fontSize: 17, color: AppColors.muted)),
                    const SizedBox(height: 28),
                    AppField(
                        label: 'Phone or email',
                        controller: _id,
                        keyboard: TextInputType.emailAddress,
                        validator: Validators.phoneOrEmail),
                    AppField(
                        label: 'Password',
                        controller: _pass,
                        obscure: true,
                        validator: (v) => Validators.required(v, 'Password')),
                    FilledButton(onPressed: _login, child: const Text('Log in')),
                    const SizedBox(height: 14),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('New here?', style: TextStyle(color: AppColors.muted)),
                      TextButton(
                          onPressed: () => Navigator.pushNamed(context, Routes.register),
                          child: const Text('Register')),
                    ]),
                  ]),
                ),
              ),
              const Text('NO LOGIN NEEDED',
                  style: TextStyle(letterSpacing: 1.4, fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.map),
                  child: const Text('View Safety Map')),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.report),
                  child: const Text('Report Anonymously')),
            ]),
          ),
        ),
      );
}
