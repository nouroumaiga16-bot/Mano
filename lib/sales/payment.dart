import '../data/database.dart';

String paymentLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Espèces',
  PaymentMethod.orangeMoney => 'Orange Money',
  PaymentMethod.moovMoney => 'Moov Money',
  PaymentMethod.wave => 'Wave',
};

/// Mode de paiement affiché pour une vente (« À crédit » si rien n'a été payé).
String salePaymentLabel(Sale sale) =>
    sale.amountPaid == 0 ? 'À crédit' : paymentLabel(sale.paymentMethod);
