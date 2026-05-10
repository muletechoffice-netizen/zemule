String? formatZambiaDialer(String? raw) {
  if (raw == null) return null;
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('260')) {
    digits = digits.substring(3);
  }
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.isEmpty) return null;
  return '+260$digits';
}

String? formatZambiaWhatsApp(String? raw) {
  if (raw == null) return null;
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('260')) {
    digits = digits.substring(3);
  }
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.isEmpty) return null;
  return '260$digits';
}

bool hasPhoneNumber(String? raw) {
  if (raw == null) return false;
  return raw.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;
}
