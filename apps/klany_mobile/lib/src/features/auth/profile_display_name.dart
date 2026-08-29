/// Имя в профиле: без эмодзи в начале (раньше ошибочно писали в [displayName]).
class ProfileDisplayName {
  ProfileDisplayName._();

  static final RegExp _leadingEmoji = RegExp(
    r'^(?:\s*[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}])+\s*',
    unicode: true,
  );

  static String sanitize(String raw) {
    var t = raw.trim();
    while (_leadingEmoji.hasMatch(t)) {
      t = t.replaceFirst(_leadingEmoji, '').trim();
    }
    return t;
  }

  static String forUi(String raw, {String fallback = 'Без имени'}) {
    final s = sanitize(raw);
    if (s.isEmpty || s == 'Родитель' || s == 'Без имени') return fallback;
    return s;
  }

  static String initial(String? raw) => sanitize(raw ?? '');
}

String parentProfileAvatarUserKey(String userId) => 'parent-profile:$userId';
