import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/osm_map.dart';

/// S12 Anonymous Report. Works without login. No name or phone is attached.
class S12Report extends StatefulWidget {
  const S12Report({super.key});
  @override
  State<S12Report> createState() => _S12State();
}

class _S12State extends State<S12Report> {
  static const categories = [
    'Harassment', 'Stalking', 'Unsafe location',
    'Suspicious activity', 'Poor lighting', 'Other safety concern',
  ];
  final _key = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _desc = TextEditingController();
  String? _cat;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  LatLng? _point;

  @override
  void dispose() {
    _location.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final when = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    // TODO(Tanisha's API): POST /api/reports with NO user identity attached.
    AppState.I.submitReport(_cat!, _location.text.trim(), _desc.text.trim(), when,
        _point?.latitude, _point?.longitude);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report saved'),
        content: const Text(
            'Nothing identifying you was attached. Demo mode: it is saved in the app and will reach campus analytics once the backend is connected.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: SafeArea(
          child: Form(
            key: _key,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const AppCard(
                child: Row(children: [
                  Icon(Icons.visibility_off_outlined, color: AppColors.teal),
                  SizedBox(width: 12),
                  Expanded(child: Text('Anonymous: your name and phone number are not attached.')),
                ]),
              ),
              const FieldLabel('Incident category'),
              DropdownButtonFormField<String>(
                value: _cat,
                hint: const Text('Choose a category'),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _cat = v),
                validator: (v) => v == null ? 'Choose a category' : null,
              ),
              const SizedBox(height: 18),
              AppField(
                  label: 'Location (e.g. Library back gate)',
                  controller: _location,
                  validator: (v) => Validators.required(v, 'Location')),
              const FieldLabel('Tap the map to mark the spot (optional)'),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  child: OsmMap(
                    center: _point ?? AppConfig.campusCenter,
                    zoom: AppConfig.campusZoom,
                    points: _point == null ? const [] : [_point!],
                    onTap: (p) => setState(() => _point = p),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const FieldLabel('Date and time of incident'),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: _pickDate, child: Text(fmtDate(_date)))),
                const SizedBox(width: 12),
                Expanded(
                    child: OutlinedButton(
                        onPressed: _pickTime, child: Text(_time.format(context)))),
              ]),
              const SizedBox(height: 18),
              AppField(label: 'Description (optional)', controller: _desc, maxLines: 4),
              FilledButton(onPressed: _submit, child: const Text('Submit report')),
            ]),
          ),
        ),
      );
}
