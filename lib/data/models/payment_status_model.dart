/// Payment Status Model
/// 
/// Represents the payment status response from the backend API
class PaymentStatusModel {
  final bool success;
  final String paymentStatus; // 'pending', 'paid', 'failed', 'expired'
  final String orderStatus; // 'new', 'processing', 'shipped', 'completed', 'refunded'
  final String? transactionStatus; // Midtrans transaction status
  final bool statusUpdated; // true if status was just updated
  final String message;

  PaymentStatusModel({
    required this.success,
    required this.paymentStatus,
    required this.orderStatus,
    this.transactionStatus,
    required this.statusUpdated,
    required this.message,
  });

  factory PaymentStatusModel.fromJson(Map<String, dynamic> json) {
    String normalizeString(dynamic v, {required String fallback}) {
      final s = (v as String?)?.trim();
      if (s == null || s.isEmpty) return fallback;
      return s.toLowerCase();
    }

    return PaymentStatusModel(
      success: json['success'] as bool? ?? true,
      // Normalize to lowercase so UI logic is resilient to backend casing/variants
      paymentStatus: normalizeString(json['payment_status'], fallback: 'pending'),
      orderStatus: normalizeString(json['order_status'], fallback: 'new'),
      transactionStatus: (json['transaction_status'] as String?)?.trim().toLowerCase(),
      statusUpdated: json['status_updated'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'payment_status': paymentStatus,
      'order_status': orderStatus,
      'transaction_status': transactionStatus,
      'status_updated': statusUpdated,
      'message': message,
    };
  }

  /// Backend `payment_status` isn't always consistent (e.g. 'PAID', 'success').
  /// Also, Midtrans' `transaction_status` may indicate success even if payment_status
  /// hasn't been updated yet.
  bool get isPaid {
    if (paymentStatus == 'paid' || paymentStatus == 'success' || paymentStatus == 'settlement') {
      return true;
    }
    // Midtrans successful statuses (depends on payment method)
    return transactionStatus == 'settlement' || transactionStatus == 'capture';
  }

  bool get isPending {
    // Some backends use 'pending' or 'unpaid'
    return paymentStatus == 'pending' || paymentStatus == 'unpaid';
  }

  bool get isFailed {
    return paymentStatus == 'failed' ||
        paymentStatus == 'deny' ||
        paymentStatus == 'canceled' ||
        paymentStatus == 'cancel' ||
        transactionStatus == 'deny' ||
        transactionStatus == 'cancel';
  }

  bool get isExpired {
    return paymentStatus == 'expired' || paymentStatus == 'expire' || transactionStatus == 'expire';
  }
  bool get isFinal => isPaid || isFailed || isExpired;

  @override
  String toString() {
    return 'PaymentStatusModel(success: $success, paymentStatus: $paymentStatus, orderStatus: $orderStatus, transactionStatus: $transactionStatus, statusUpdated: $statusUpdated, message: $message)';
  }
}
