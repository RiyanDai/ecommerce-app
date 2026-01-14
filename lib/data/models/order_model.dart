class OrderItemModel {
  final int id;
  final int? orderId;
  final int? productId;
  final String productName;
  final double productPrice;
  final int quantity;
  final double subtotal;

  OrderItemModel({
    required this.id,
    this.orderId,
    this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '0') ?? 0.0;
    }

    return OrderItemModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      orderId: json['order_id'] is int
          ? json['order_id'] as int
          : int.tryParse('${json['order_id']}'),
      productId: json['product_id'] is int
          ? json['product_id'] as int
          : int.tryParse('${json['product_id']}'),
      productName: json['product_name']?.toString() ?? '',
      productPrice: parseDouble(json['product_price']),
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : int.tryParse('${json['quantity']}') ?? 0,
      subtotal: parseDouble(json['subtotal']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'product_price': productPrice,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }
}

class OrderModel {
  final int id;
  final int? userId;
  final String orderNumber;
  final double totalAmount;
  final String status; // Deprecated: use orderStatus
  final String? paymentStatus; // pending, paid, failed, expired
  final String? orderStatus; // new, processing, shipped, completed, refunded
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String shippingAddress;
  final DateTime? orderDate;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    this.userId,
    required this.orderNumber,
    required this.totalAmount,
    required this.status,
    this.paymentStatus,
    this.orderStatus,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.shippingAddress,
    this.orderDate,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '0') ?? 0.0;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    final itemsJson = json['items'];
    final List<OrderItemModel> parsedItems = [];
    if (itemsJson is List) {
      for (final item in itemsJson) {
        if (item is Map<String, dynamic>) {
          parsedItems.add(OrderItemModel.fromJson(item));
        }
      }
    }

    // Handle order_items or items
    final orderItemsJson = json['order_items'] ?? json['items'];
    final List<OrderItemModel> parsedOrderItems = [];
    if (orderItemsJson is List) {
      for (final item in orderItemsJson) {
        if (item is Map<String, dynamic>) {
          // Handle nested product structure from API
          final product = item['product'] as Map<String, dynamic>?;
          parsedOrderItems.add(OrderItemModel(
            id: item['id'] is int ? item['id'] as int : int.tryParse('${item['id']}') ?? 0,
            orderId: item['order_id'] is int
                ? item['order_id'] as int
                : int.tryParse('${item['order_id']}'),
            productId: item['product_id'] is int
                ? item['product_id'] as int
                : int.tryParse('${item['product_id']}'),
            productName: product?['name']?.toString() ?? item['product_name']?.toString() ?? '',
            productPrice: parseDouble(product?['price'] ?? item['price'] ?? item['product_price']),
            quantity: item['quantity'] is int
                ? item['quantity'] as int
                : int.tryParse('${item['quantity']}') ?? 0,
            subtotal: parseDouble(item['subtotal']),
          ));
        }
      }
    }

    return OrderModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse('${json['user_id']}'),
      orderNumber: json['order_number']?.toString() ?? '',
      totalAmount: parseDouble(json['total_amount']),
      status: json['status']?.toString() ?? json['order_status']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString(),
      orderStatus: json['order_status']?.toString(),
      customerName: json['customer_name']?.toString() ?? '',
      customerEmail: json['customer_email']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      shippingAddress: json['shipping_address']?.toString() ?? '',
      orderDate: parseDate(json['created_at'] ?? json['order_date']),
      items: parsedOrderItems.isNotEmpty ? parsedOrderItems : parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'order_number': orderNumber,
      'total_amount': totalAmount,
      'status': status,
      'payment_status': paymentStatus,
      'order_status': orderStatus,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'customer_phone': customerPhone,
      'shipping_address': shippingAddress,
      'order_date': orderDate?.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}


