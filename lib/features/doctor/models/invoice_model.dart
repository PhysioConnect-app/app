enum InvoiceStatus { pending, paid, insuranceClaim, cancelled }

extension InvoiceStatusX on InvoiceStatus {
  String get key => switch (this) {
    InvoiceStatus.pending => 'pending',
    InvoiceStatus.paid => 'paid',
    InvoiceStatus.insuranceClaim => 'insurance_claim',
    InvoiceStatus.cancelled => 'cancelled',
  };

  static InvoiceStatus from(String? raw) => switch (raw) {
    'paid' => InvoiceStatus.paid,
    'insurance_claim' => InvoiceStatus.insuranceClaim,
    'cancelled' => InvoiceStatus.cancelled,
    _ => InvoiceStatus.pending,
  };
}

class Invoice {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String service;
  final double amount;
  final String currency;
  final InvoiceStatus status;
  final DateTime invoiceDate;
  final DateTime createdAt;

  Invoice({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.service,
    required this.amount,
    required this.currency,
    required this.status,
    required this.invoiceDate,
    required this.createdAt,
  });

  factory Invoice.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(String? s) =>
        s != null ? DateTime.parse(s) : DateTime.now();
    return Invoice(
      id: data['id'] as String? ?? '',
      doctorId: data['doctor_id'] as String? ?? '',
      patientId: data['patient_id'] as String? ?? '',
      patientName: data['patient_name'] as String? ?? 'Patient',
      service: data['service'] as String? ?? 'Physical Therapy',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'USD',
      status: InvoiceStatusX.from(data['status'] as String?),
      invoiceDate: parseDate(
          (data['invoice_date'] ?? data['created_at']) as String?),
      createdAt: parseDate(data['created_at'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'doctor_id': doctorId,
    'patient_id': patientId,
    'patient_name': patientName,
    'service': service,
    'amount': amount,
    'currency': currency,
    'status': status.key,
    'invoice_date': invoiceDate.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

class BillingSummary {
  final double totalRevenue;
  final double pendingTotal;
  final double insuranceTotal;
  final int completedCount;
  final String currency;

  BillingSummary({
    required this.totalRevenue,
    required this.pendingTotal,
    required this.insuranceTotal,
    required this.completedCount,
    required this.currency,
  });

  factory BillingSummary.fromInvoices(List<Invoice> invoices) {
    double totalRevenue = 0, pendingTotal = 0, insuranceTotal = 0;
    int completedCount = 0;
    String currency = invoices.isEmpty ? 'USD' : invoices.first.currency;

    for (final invoice in invoices) {
      switch (invoice.status) {
        case InvoiceStatus.paid:
          totalRevenue += invoice.amount;
          completedCount++;
        case InvoiceStatus.pending:
          pendingTotal += invoice.amount;
        case InvoiceStatus.insuranceClaim:
          insuranceTotal += invoice.amount;
        case InvoiceStatus.cancelled:
          break;
      }
    }

    return BillingSummary(
      totalRevenue: totalRevenue,
      pendingTotal: pendingTotal,
      insuranceTotal: insuranceTotal,
      completedCount: completedCount,
      currency: currency,
    );
  }
}
