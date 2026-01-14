import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/models/order_model.dart';
import '../../data/services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService = OrderService();

  final List<OrderModel> _orders = [];
  OrderModel? _selectedOrder;
  bool _isLoading = false;

  List<OrderModel> get orders => List.unmodifiable(_orders);
  OrderModel? get selectedOrder => _selectedOrder;
  bool get isLoading => _isLoading;

  String? _lastOrderNumber;

  String? get lastOrderNumber => _lastOrderNumber;

  Future<Map<String, dynamic>?> checkout({required String customerName, required String email}) async {
    _setLoading(true);
    _lastOrderNumber = null;
    try {
      final response = await _orderService.checkout();
      if (response.success) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null) {
          _lastOrderNumber = data['order_number']?.toString();
          return data;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _setLoading(false);
    }
  }

   Future<void> fetchOrders() async {
  _setLoading(true);
  try {
    final response = await _orderService.getOrders();

    if (!response.success) return;

    final raw = response.data;

    debugPrint('ORDER RAW TYPE: ${raw.runtimeType}');
    debugPrint('ORDER RAW DATA: $raw');

    List list = [];

    if (raw is List) {
      // API langsung return array
      list = raw;
    } else if (raw is Map<String, dynamic>) {
      // Laravel response umum
      if (raw['data'] is List) {
        list = raw['data'];
      } else if (raw['orders'] is List) {
        list = raw['orders'];
      } else if (raw['data'] is Map &&
          raw['data']['data'] is List) {
        // Pagination Laravel
        list = raw['data']['data'];
      }
    }

    _orders
      ..clear()
      ..addAll(
        list
            .whereType<Map<String, dynamic>>()
            .map(OrderModel.fromJson)
            .toList(),
      );

    _notifySafe();
  } catch (e) {
    debugPrint('FETCH ORDERS ERROR: $e');
  } finally {
    _setLoading(false);
  }
}

  Future<void> fetchOrderDetail(int orderId) async {
    _setLoading(true);
    try {
      final response = await _orderService.getOrderDetail(orderId);
      
      if (!response.success) {
        debugPrint('FETCH ORDER DETAIL FAILED: ${response.message}');
        _selectedOrder = null;
        _notifySafe();
        return;
      }

      final raw = response.data;
      debugPrint('ORDER DETAIL RAW TYPE: ${raw.runtimeType}');
      debugPrint('ORDER DETAIL RAW DATA: $raw');

      Map<String, dynamic>? orderData;

      if (raw is Map<String, dynamic>) {
        // Cek berbagai struktur response yang mungkin
        if (raw['data'] is Map<String, dynamic>) {
          orderData = raw['data'] as Map<String, dynamic>;
        } else if (raw['order'] is Map<String, dynamic>) {
          orderData = raw['order'] as Map<String, dynamic>;
        } else {
          // Langsung pakai raw jika sudah Map
          orderData = raw;
        }
      }

      if (orderData != null) {
        _selectedOrder = OrderModel.fromJson(orderData);
        _notifySafe();
      } else {
        debugPrint('ORDER DETAIL DATA NOT FOUND');
        _selectedOrder = null;
        _notifySafe();
      }
    } catch (e) {
      debugPrint('FETCH ORDER DETAIL ERROR: $e');
      _selectedOrder = null;
      _notifySafe();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelOrder(int orderId) async {
    _setLoading(true);
    try {
      final response = await _orderService.cancelOrder(orderId);
      if (response.success) {
        await fetchOrders();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _setLoading(false);
    }
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
