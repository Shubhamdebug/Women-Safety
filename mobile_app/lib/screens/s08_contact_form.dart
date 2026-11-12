import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// S08 Add / Edit Contact. Arrow: save -> back to S07.
class S08ContactForm extends StatefulWidget {
  const S08ContactForm({super.key});
  @override
  State<S08ContactForm> createState() => _S08State();
}

class _S08State extends State<S08ContactForm> {
  static const relations = ['Parent', 'Sibling', 'Friend', 'Partner', 'Warden', 'Other'];
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _rel = 'Friend';
  Contact? _editing;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Contact) {
      _editing = arg;
      _name.text = arg.name;
      _phone.text = arg.phone;
      _rel = arg.relationship;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final n = _name.text.trim();
    final p = _phone.text.replaceAll(RegExp(r'[\s-]'), '');
    if (_editing == null) {
      AppState.I.addContact(n, p, _rel);
    } else {
      AppState.I.updateContact(_editing!, n, p, _rel);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_editing == null ? 'Add contact' : 'Edit contact')),
        body: SafeArea(
          child: Form(
            key: _key,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              AppField(label: 'Contact name', controller: _name,
                  validator: (v) => Validators.required(v, 'Name')),
              AppField(label: 'Phone number', controller: _phone,
                  keyboard: TextInputType.phone, validator: Validators.phone),
              const FieldLabel('Relationship'),
              DropdownButtonFormField<String>(
                value: _rel,
                items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _rel = v ?? _rel),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ]),
          ),
        ),
      );
}
