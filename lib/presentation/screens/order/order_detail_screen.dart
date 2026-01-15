import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/order_provider.dart';
import '../../providers/payment_provider.dart';
import '../payment/payment_webview_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  static const String routeName = '/order-detail';

  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy HH:mm');
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      final id = ModalRoute.of(context)?.settings.arguments as int?;
      if (id != null && id > 0) {
        debugPrint('Loading order detail for ID: $id');
        _hasLoaded = true;
        // Delay fetchOrderDetail until after build completes
        Future.microtask(() {
          if (mounted) {
            context.read<OrderProvider>().fetchOrderDetail(id);
          }
        });
      } else {
        debugPrint('Invalid order ID: $id');
      }
    }
  }

  Future<void> _cancelOrder(int orderId) async {
    final provider = context.read<OrderProvider>();
    final errorMessage = await provider.cancelOrder(orderId);
    if (!mounted) return;
    if (errorMessage == null) {
      // Success
      Fluttertoast.showToast(msg: 'Order cancelled');
      Navigator.of(context).pop();
    } else {
      // Failed - show actual error message
      Fluttertoast.showToast(msg: errorMessage);
    }
  }

  Future<void> _retryPayment(String orderNumber) async {
    if (!mounted) return;

    // Navigate to Payment WebView Screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(orderNumber: orderNumber),
      ),
    );

    // Refresh order detail after payment
    if (mounted) {
      final id = ModalRoute.of(context)?.settings.arguments as int?;
      if (id != null && id > 0) {
        context.read<OrderProvider>().fetchOrderDetail(id);
      }
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getOrderStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'shipped':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final order = orderProvider.selectedOrder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Detail'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: orderProvider.isLoading && order == null
          ? const Center(child: CircularProgressIndicator())
          : order == null
              ? const Center(child: Text('Order not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Number & Date
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order Number',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          order.orderNumber ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    order.orderDate != null
                                        ? _dateFormat.format(order.orderDate!)
                                        : 'N/A',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment & Order Status
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Payment Status
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Payment Status'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPaymentStatusColor(order.paymentStatus)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _getPaymentStatusColor(order.paymentStatus),
                                      ),
                                    ),
                                    child: Text(
                                      (order.paymentStatus ?? 'N/A').toUpperCase(),
                                      style: TextStyle(
                                        color: _getPaymentStatusColor(order.paymentStatus),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Order Status
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Order Status'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getOrderStatusColor(order.status)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _getOrderStatusColor(order.status),
                                      ),
                                    ),
                                    child: Text(
                                      (order.status ?? 'N/A').toUpperCase(),
                                      style: TextStyle(
                                        color: _getOrderStatusColor(order.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Customer Info
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(Icons.person, order.customerName),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.email, order.customerEmail),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.phone, order.customerPhone),
                              const SizedBox(height: 12),
                              const Text(
                                'Shipping Address',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(order.shippingAddress),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Order Items
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Items',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...order.items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.productName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.quantity} x ${_currency.format(item.productPrice)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _currency.format(item.subtotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _currency.format(order.totalAmount),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      if (order.paymentStatus?.toLowerCase() == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: orderProvider.isLoading
                                ? null
                                : () => _retryPayment(order.orderNumber ?? ''),
                            icon: const Icon(Icons.payment, color: Colors.white),
                            label: const Text(
                              'Pay Now',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      if (order.paymentStatus?.toLowerCase() == 'pending')
                        const SizedBox(height: 12),
                      // Show cancel button if payment is not paid and order is not already cancelled
                      if (order.paymentStatus?.toLowerCase() != 'paid' && 
                          order.status?.toLowerCase() != 'cancelled')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: orderProvider.isLoading
                                ? null
                                : () => _cancelOrder(order.id),
                            icon: orderProvider.isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cancel),
                            label: const Text('Cancel Order'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

