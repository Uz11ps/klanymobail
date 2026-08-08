const kFamilyAccessCodeLength = 8;

final RegExp kFamilyAccessCodePattern = RegExp(r'^\d{8}$');

/// Принимаем и старый 6-значный ввод (сервер дополняет до 8).
bool isValidFamilyAccessCode(String raw) {
  final code = raw.trim();
  return kFamilyAccessCodePattern.hasMatch(code) ||
      RegExp(r'^\d{6}$').hasMatch(code);
}

String get kFamilyAccessCodeDigitsHint => '0' * kFamilyAccessCodeLength;

int get kFamilyAccessCodeInputMaxLength => kFamilyAccessCodeLength;
