import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/payment_provider.dart';
import '../payment/payment_webview_screen.dart';

class CheckoutScreen extends StatefulWidget {
  static const String routeName = '/checkout';

  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  bool _isProcessingPayment = false;

  String _getCustomerName() {
    final authProvider = context.read<AuthProvider>();
    return authProvider.currentUser?.name ?? '';
  }

  String _getCustomerEmail() {
    final authProvider = context.read<AuthProvider>();
    return authProvider.currentUser?.email ?? '';
  }

  Future<void> _submit() async {
    final orderProvider = context.read<OrderProvider>();
    final cartProvider = context.read<CartProvider>();

    // Create order (new API: empty body - cart items are used automatically)
    final orderData = await orderProvider.checkout(customerName: _getCustomerName(), email: _getCustomerEmail());

    if (!mounted) return;
    
    if (orderData == null) {
      Fluttertoast.showToast(msg: 'Failed to create order');
      return;
    }

    final orderNumber = orderData['order_number']?.toString();
    if (orderNumber == null || orderNumber.isEmpty) {
      Fluttertoast.showToast(msg: 'Failed to get order number');
      return;
    }

    // Clear cart after order created
    cartProvider.clearCartLocal();
    
    // Start payment flow
    await _startPayment(orderNumber);
  }

  Future<void> _startPayment(String orderNumber) async {
    if (!mounted) return;
    
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Navigate to Payment WebView Screen
      // PaymentWebViewScreen will handle:
      // 1. Generate snap token
      // 2. Display Midtrans Snap in WebView
      // 3. Poll payment status
      // 4. Navigate to orders when done
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(orderNumber: orderNumber),
        ),
      );
    } catch (e) {
      debugPrint('Error starting payment: $e');
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Failed to start payment: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final orderProvider = context.watch<OrderProvider>();

    double discount = cartProvider.totalAmount * 0.1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.person, size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Name',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getCustomerName().isNotEmpty 
                                    ? _getCustomerName() 
                                    : 'Not available',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Email
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.email, size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getCustomerEmail().isNotEmpty 
                                    ? _getCustomerEmail() 
                                    : 'Not available',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...cartProvider.cartItems.map(
                (item) => ListTile(
                  dense: true,
                  title: Text(item.product?.name ?? 'Product'),
                  trailing: Text(
                    '${item.quantity} x ${_currency.format(item.product?.price ?? 0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Sub: ${_currency.format(cartProvider.totalAmount)}',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Discount: 10%',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${_currency.format(cartProvider.totalAmount - discount)}',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (orderProvider.isLoading || _isProcessingPayment)
                    ? null
                    : _submit,
                child: (orderProvider.isLoading || _isProcessingPayment)
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Place Order & Pay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
