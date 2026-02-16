enum AppRole {
  parent,
  child,
}

extension AppRoleX on AppRole {
  String get key => switch (this) {
        AppRole.parent => 'parent',
        AppRole.child => 'child',
      };

  static AppRole? fromKey(String? value) {
    return switch (value) {
      'parent' => AppRole.parent,
      'child' => AppRole.child,
      _ => null,
    };
  }
}

