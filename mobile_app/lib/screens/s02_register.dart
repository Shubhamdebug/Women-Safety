import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S02 Register. Arrow: back to S01 Login ("registered").
class S02Register extends StatefulWidget {
  const S02Register({super.key});
  @override
  State<S02Register> createState() => _S02State();
}

class _S02State extends State<S02Register> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    // TODO(Tanisha's API): POST /api/auth/register (backend hashes the password)
    final err = AppState.I.register(
        _name.text.trim(), _phone.text.trim(), _email.text.trim(), _pass.text);
    if (err != null) return snack(context, err);
    Navigator.pop(context);
    snack(context, 'Account created. Please log in.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Register')),
        body: SafeArea(
          child: Form(
            key: _key,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              AppField(label: 'Full name', controller: _name,
                  validator: (v) => Validators.required(v, 'Name')),
              AppField(label: 'Phone number', controller: _phone,
                  keyboard: TextInputType.phone, validator: Validators.phone),
              AppField(label: 'Email', controller: _email,
                  keyboard: TextInputType.emailAddress, validator: Validators.email),
              AppField(label: 'Password', controller: _pass, obscure: true,
                  validator: Validators.password),
              AppField(label: 'Confirm password', controller: _confirm, obscure: true,
                  validator: (v) => v != _pass.text ? 'Passwords do not match' : null),
              FilledButton(onPressed: _submit, child: const Text('Create account')),
            ]),
          ),
        ),
      );
}
