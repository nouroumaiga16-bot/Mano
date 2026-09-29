import '../data/database.dart';

String paymentLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Espèces',
  PaymentMethod.orangeMoney => 'Orange Money',
  PaymentMethod.moovMoney => 'Moov Money',
  PaymentMethod.wave => 'Wave',
};
