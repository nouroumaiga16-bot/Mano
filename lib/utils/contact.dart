import 'package:url_launcher/url_launcher.dart';

import 'format.dart';

/// Numéro au format international sans « + » (226XXXXXXXX), ou null si le
/// numéro n'est pas reconnu.
String? internationalPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 8) return '226$digits';
  if (digits.length == 11 && digits.startsWith('226')) return digits;
  if (digits.length == 13 && digits.startsWith('00226')) {
    return digits.substring(2);
  }
  return null;
}

/// Lien qui ouvre WhatsApp avec le message déjà écrit.
Uri? whatsappUri(String phone, String message) {
  final number = internationalPhone(phone);
  if (number == null) return null;
  return Uri.https('wa.me', '/$number', {'text': message});
}

Uri callUri(String phone) =>
    Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));

/// Message de rappel poli pour une dette.
String reminderMessage({
  required String customerName,
  required int balance,
  required String shopName,
}) {
  final from = shopName.isEmpty ? '' : ' chez $shopName';
  // Espaces normales : l'espace fine s'affiche mal dans certains WhatsApp.
  final amount = formatFcfa(balance).replaceAll(' ', ' ');
  return 'Bonjour $customerName, petit rappel : il reste $amount à régler'
      '$from. Merci beaucoup !';
}

Future<bool> openUri(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
