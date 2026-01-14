import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/models/cart_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/cart_service.dart';

class CartProvider extends ChangeNotifier {
  final CartService _cartService = CartService();

  final List<CartModel> _items = [];
  bool _isLoading = false;

  List<CartModel> get cartItems => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  double get totalAmount {
    double total = 0;
    for (final item in _items) {
      final price = item.product?.price ?? 0;
      total += price * item.quantity;
    }
    return total;
  }

  int get itemCount {
    int count = 0;
    for (final item in _items) {
      count += item.quantity;
    }
    return count;
  }

  Future<void> fetchCart() async {
    _setLoading(true);
    try {
      final response = await _cartService.getCart();
      if (response.success) {
        _items.clear();
        final data = response.data;

        List<dynamic> rawList = const [];
        if (data is List) {
          rawList = data;
        } else if (data is Map<String, dynamic>) {
          // Coba beberapa kemungkinan struktur data dari Laravel
          if (data['data'] is List) {
            rawList = data['data'] as List;
          } else if (data['items'] is List) {
            rawList = data['items'] as List;
          } else if (data['cart'] is List) {
            rawList = data['cart'] as List;
          }
        }

        _items.addAll(
          rawList
              .whereType<Map<String, dynamic>>()
              .map((e) => CartModel.fromJson(e))
              .toList(),
        );
        _notifySafe();
      }
    } catch (_) {
      // ignore for now; UI will just show empty
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addToCart(ProductModel product, int quantity) async {
    _setLoading(true);
    try {
      final response = await _cartService.addToCart(product.id, quantity);
      if (response.success) {
        await fetchCart();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateQuantity(CartModel item, int quantity) async {
    if (quantity <= 0) return;
    _setLoading(true);
    try {
      final response = await _cartService.updateCart(item.id, quantity);
      if (response.success) {
        await fetchCart();
      }
    } catch (_) {
      // ignore
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeItem(CartModel item) async {
    _setLoading(true);
    try {
      final response = await _cartService.removeFromCart(item.id);
      if (response.success) {
        _items.removeWhere((e) => e.id == item.id);
        _notifySafe();
      }
    } catch (_) {
      // ignore
    } finally {
      _setLoading(false);
    }
  }

  void clearCartLocal() {
    _items.clear();
    _notifySafe();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _notifySafe();
  }

  void _notifySafe() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }
}


