/// Единые правила пароля (в ногу с [backend/src/auth/password-policy.ts]).
class KlanyPasswordRules {
  KlanyPasswordRules._();

  static const minLength = 8;
  static const maxLength = 128;

  /// Разрешено: латиница/кириллица + цифры + символы `!@#$%^&*()_+-=[]{}|;:,./?` без пробелов.
  /// Запрещены пробелы, кавычки, `\`, `<`, `>` и прочее вне набора — чтобы не ломать сериализацию и разбор.
  static final RegExp allowedCharset = RegExp(
    r'^[a-zA-Zа-яА-ЯёЁ0-9!@#$%^&*()_+\-=\[\]{}|;:,./?]+$',
    unicode: true,
  );

  /// `null`, если всё ок; иначе короткая строка для SnackBar / TextFormField error.
  static String? validatePlain(String raw) {
    if (raw.length < minLength) {
      return 'Пароль: минимум $minLength символов';
    }
    if (raw.length > maxLength) {
      return 'Пароль: не более $maxLength символов';
    }
    if (RegExp(r'\s').hasMatch(raw)) {
      return 'Пароль не должен содержать пробелов';
    }
    if (!allowedCharset.hasMatch(raw)) {
      return 'Только буквы, цифры и !@#\$%^&*()_+-=[]{}|;:,./?';
    }
    return null;
  }
}
