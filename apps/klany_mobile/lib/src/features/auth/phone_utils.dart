import '../../core/env.dart';

String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+')) return digits;
  // Default: treat as local digits, prefix '+' if user typed numbers only.
  return '+$digits';
}

String kidsPseudoEmailFromPhone(String rawPhone) {
  final phone = normalizePhone(rawPhone);
  // Supabase email auth expects a valid-ish email. We map phone to a deterministic email.
  final local = phone.replaceAll('+', '').replaceAll(RegExp(r'[^0-9]'), '');
  return '$local@${Env.kidsEmailDomain}';
}

