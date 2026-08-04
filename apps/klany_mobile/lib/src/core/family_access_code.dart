const kFamilyAccessCodeLength = 8;

final RegExp kFamilyAccessCodePattern = RegExp(r'^\d{8}$');

String get kFamilyAccessCodeDigitsHint => '0' * kFamilyAccessCodeLength;
