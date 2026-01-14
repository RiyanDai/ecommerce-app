import 'product_model.dart';

class CartModel {
  final int id;
  final int? userId;
  final int? productId;
  final int quantity;
  final ProductModel? product;

  CartModel({
    required this.id,
    this.userId,
    this.productId,
    required this.quantity,
    this.product,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse('${json['user_id']}'),
      productId: json['product_id'] is int
          ? json['product_id'] as int
          : int.tryParse('${json['product_id']}'),
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : int.tryParse('${json['quantity']}') ?? 0,
      product: json['product'] is Map<String, dynamic>
          ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'product': product?.toJson(),
    };
  }
}


