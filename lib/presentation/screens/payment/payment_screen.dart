import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../data/services/payment_service.dart';

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
            print('WebView error: ${error.description}');
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
        print('Error checking payment status: $e');
      }
    });
  }

  void _handlePaymentSuccess() {
    _statusCheckTimer?.cancel();
    if (!mounted) return;
    
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment successful!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handlePaymentFailed() {
    _statusCheckTimer?.cancel();
    if (!mounted) return;
    
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment failed. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handlePaymentExpired() {
    _statusCheckTimer?.cancel();
    if (!mounted) return;
    
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment expired. Please try again.'),
        backgroundColor: Colors.orange,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

