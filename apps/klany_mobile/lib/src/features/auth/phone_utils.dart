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

int _digitsOnlyLength(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '').length;

/// Вход / автосоздание главы: строка должна быть **либо** email с `@`, **либо** телефон (достаточно цифр).
/// `null` — ок; иначе короткое сообщение для SnackBar.
String? validateParentLoginIdentifier(String raw) {
  final t = raw.trim();
  if (t.isEmpty) {
    return 'Введите email или номер телефона';
  }
  if (t.contains('@')) {
    final ok = RegExp(
      r'^[^@\s]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(t);
    if (!ok) {
      return 'Введите email в формате user@example.com';
    }
    return null;
  }
  if (_digitsOnlyLength(t) < 10) {
    return 'Введите корректный номер телефона или email с @';
  }
  return null;
}
