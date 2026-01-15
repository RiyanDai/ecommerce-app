import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../data/services/payment_service.dart';
import '../../providers/payment_provider.dart';
import '../../providers/order_provider.dart';
import '../home/home_screen.dart';
import 'payment_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  static const String routeName = '/payment';
  static const String argOrderNumber = 'order_number';
  static const String argSnapToken = 'snap_token';

  final String orderNumber;
  final String snapToken;

  const PaymentScreen({
    super.key,
    required this.orderNumber,
    required this.snapToken,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  Timer? _statusCheckTimer;
  bool _hasNavigated = false;

  // TODO: Set your Midtrans environment (sandbox or production)
  static const String _midtransBaseUrl = 'https://app.sandbox.midtrans.com';
  // For production use: 'https://app.midtrans.com'

  @override
  void initState() {
    super.initState();
    
    final snapUrl = '$_midtransBaseUrl/snap/v2/vtweb/${widget.snapToken}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            
            // Check if payment completed
            if (url.contains('status_code=200') || 
                url.contains('status_code=201') ||
                url.contains('transaction_status=settlement')) {
              _handlePaymentSuccess();
            } else if (url.contains('status_code=407') || 
                       url.contains('transaction_status=expire')) {
              _handlePaymentExpired();
            } else if (url.contains('status_code=202') || 
                       url.contains('transaction_status=deny')) {
              _handlePaymentFailed();
            }
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(snapUrl));

    // Start periodic status check
    _startStatusPolling();
  }

  void _startStatusPolling() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final result = await _paymentService.checkPaymentStatus(widget.orderNumber);
        final paymentStatus = result['payment_status'] as String;
        final statusUpdated = result['status_updated'] as bool;

        if (statusUpdated && paymentStatus == 'paid') {
          timer.cancel();
          _handlePaymentSuccess();
        } else if (paymentStatus == 'failed' || paymentStatus == 'expired') {
          timer.cancel();
          if (paymentStatus == 'failed') {
            _handlePaymentFailed();
          } else {
            _handlePaymentExpired();
          }
        }
      } catch (e) {
        // Silent error handling
      }
    });
  }

  void _handlePaymentSuccess() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _statusCheckTimer?.cancel();
    
    // Find order ID from order number
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final orderId = orderProvider.findOrderIdByOrderNumber(widget.orderNumber);

    // Refresh orders to get latest data
    orderProvider.fetchOrders();

    // Navigate to success screen
    Navigator.of(context).pushReplacementNamed(
      PaymentSuccessScreen.routeName,
      arguments: {
        PaymentSuccessScreen.argOrderNumber: widget.orderNumber,
        PaymentSuccessScreen.argOrderId: orderId,
      },
    );
  }

  void _handlePaymentFailed() {
    _statusCheckTimer?.cancel();
    if (!mounted || _hasNavigated) return;
    
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran gagal. Silakan coba lagi.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _handlePaymentExpired() {
    _statusCheckTimer?.cancel();
    if (!mounted || _hasNavigated) return;
    
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran kedaluwarsa. Silakan buat pembayaran baru.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _paymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_hasNavigated) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Batalkan Pembayaran?'),
              content: const Text('Apakah Anda yakin ingin membatalkan pembayaran ini?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Tidak'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Ya, Batalkan'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              if (!_hasNavigated) {
                final shouldPop = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Batalkan Pembayaran?'),
                    content: const Text('Apakah Anda yakin ingin membatalkan pembayaran ini?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Tidak'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Ya, Batalkan'),
                      ),
                    ],
                  ),
                );
                if (shouldPop == true && mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text(
            'Pembayaran',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.9),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Memuat halaman pembayaran...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
