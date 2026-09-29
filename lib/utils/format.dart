import 'package:flutter/services.dart';

/// Espace insécable fine : évite qu'un montant soit coupé en fin de ligne.
const _nbsp = ' ';

/// Groupe les chiffres par milliers : 1250000 -> "1 250 000".
String formatNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_nbsp);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 12500 -> "12 500 FCFA".
String formatFcfa(int value) => '${formatNumber(value)}${_nbsp}FCFA';

/// Lit un nombre tapé par l'utilisateur, en ignorant les espaces.
int? parseNumber(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 28/09/2026 à 14:05
String formatDateTime(DateTime date) {
  final d = date.toLocal();
  return '${_two(d.day)}/${_two(d.month)}/${d.year} à ${_two(d.hour)}:${_two(d.minute)}';
}

/// Affiche les milliers pendant la saisie : on tape 125000, on voit 125 000.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 12) return oldValue;
    final number = parseNumber(digits);
    if (number == null) return const TextEditingValue();
    final text = formatNumber(number);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// 28/09/2026
String formatDate(DateTime date) {
  final d = date.toLocal();
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// 14:05
String formatTime(DateTime date) {
  final d = date.toLocal();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// « Aujourd'hui », « Hier » ou la date.
String formatDay(DateTime date, {DateTime? now}) {
  final d = date.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final diff = DateTime(today.year, today.month, today.day).difference(day);
  if (diff.inDays == 0) return 'Aujourd\'hui';
  if (diff.inDays == 1) return 'Hier';
  return formatDate(d);
}

/// Numéro par paires : « 60401903 » -> « 60 40 19 03 »,
/// « 0022660401903 » -> « +226 60 40 19 03 ». Autre format : laissé tel quel.
String formatPhone(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  var prefix = '';
  if (digits.length == 13 && digits.startsWith('00226')) {
    digits = digits.substring(5);
    prefix = '+226 ';
  } else if (digits.length == 11 && digits.startsWith('226')) {
    digits = digits.substring(3);
    prefix = '+226 ';
  }
  if (digits.length != 8) return phone.trim();
  final pairs = [for (var i = 0; i < 8; i += 2) digits.substring(i, i + 2)];
  return '$prefix${pairs.join(' ')}';
}
