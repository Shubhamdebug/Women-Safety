import 'package:flutter/material.dart';
import '../config/theme.dart';

String two(int n) => n.toString().padLeft(2, '0');
String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String fmtDate(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
String fmtDateTime(DateTime d) => '${fmtDate(d)} ${fmtTime(d)}';
String fmtDuration(Duration d) {
  final s = d.inSeconds.abs();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '${two(h)}:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\+?\d{10,13}$');

  static String? required(String? v, [String f = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$f is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    return _email.hasMatch(v.trim()) ? null : 'Enter a valid email';
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    return _phone.hasMatch(v.replaceAll(RegExp(r'[\s-]'), '')) ? null : 'Enter a valid phone number';
  }

  static String? phoneOrEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your phone or email';
    final t = v.trim();
    if (_email.hasMatch(t) || _phone.hasMatch(t.replaceAll(RegExp(r'[\s-]'), ''))) return null;
    return 'Enter a valid phone or email';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    return v.length < 8 ? 'Use at least 8 characters' : null;
  }
}

/// Label above the field, like the Figma design.
class AppField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final String? hint;
  const AppField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboard,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            validator: validator,
            enabled: enabled,
            maxLines: obscure ? 1 : maxLines,
            decoration: InputDecoration(hintText: hint),
          ),
        ]),
      );
}

/// Small bold label above a non-text field (dropdowns, pickers).
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

enum StepStatus { done, pending, warn }

/// One line of a status checklist. Never shows "done" unless it really is.
class StepRow extends StatelessWidget {
  final String label, detail;
  final StepStatus state;
  const StepRow({super.key, required this.label, required this.detail, required this.state});

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      StepStatus.done => const Icon(Icons.check_circle, color: AppColors.teal),
      StepStatus.pending => const SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.orange)),
      StepStatus.warn => const Icon(Icons.error_outline, color: AppColors.orange),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 24, child: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}
