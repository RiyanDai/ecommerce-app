import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/payment_provider.dart';
import '../../providers/order_provider.dart';
import '../home/home_screen.dart';
import 'payment_success_screen.dart';

class PaymentWebViewScreen extends StatefulWidget {
  static const String routeName = '/payment-webview';
  static const String argOrderNumber = 'order_number';
  
  final String orderNumber;

  const PaymentWebViewScreen({
    super.key,
    required this.orderNumber,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  WebViewController? _webViewController;
  bool _isLoadingSnapToken = true;
  bool _isWebViewLoading = true;
  bool _hasNavigated = false;
  String? _snapToken;
  String? _errorMessage;
  PaymentProvider? _paymentProvider;

  // Midtrans Snap Sandbox URL
  static const String _midtransBaseUrl = 'https://app.sandbox.midtrans.com';
  // For production use: 'https://app.midtrans.com'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePayment();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paymentProvider == null) {
      _paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
      _paymentProvider?.clearPaymentData();
    }
  }

  Future<void> _initializePayment() async {
    if (!mounted) return;

    final paymentProvider = _paymentProvider ?? Provider.of<PaymentProvider>(context, listen: false);
    if (_paymentProvider == null) {
      _paymentProvider = paymentProvider;
    }

    if (mounted) {
      setState(() {
        _isLoadingSnapToken = true;
        _errorMessage = null;
      });
    }

    try {
      final success = await paymentProvider.generateSnapToken(widget.orderNumber);

      if (success && paymentProvider.snapToken != null) {
        _snapToken = paymentProvider.snapToken;
        await _initializeWebView();
        paymentProvider.startPolling(widget.orderNumber, maxAttempts: 60);

        if (mounted) {
          setState(() {
            _isLoadingSnapToken = false;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingSnapToken = false;
            _errorMessage = paymentProvider.errorMessage ?? 'Failed to generate payment token';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSnapToken = false;
          _errorMessage = 'Error initializing payment: $e';
        });
      }
    }
  }

  Future<void> _initializeWebView() async {
    if (_snapToken == null) return;

    final snapUrl = '$_midtransBaseUrl/snap/v2/vtweb/$_snapToken';

    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              _handleUrlSideEffects(url);
              if (mounted) {
                setState(() {
                  _isWebViewLoading = true;
                });
              }
            },
            onPageFinished: (String url) {
              _handleUrlSideEffects(url);
              if (mounted) {
                setState(() {
                  _isWebViewLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _isWebViewLoading = false;
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              _handleUrlSideEffects(request.url);
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(snapUrl));

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load payment page: $e';
          _isLoadingSnapToken = false;
        });
      }
    }
  }

  void _navigateToSuccess() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    _paymentProvider?.stopPolling();

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

  void _handleUrlSideEffects(String url) {
    final lower = url.toLowerCase();

    final isSuccess = lower.contains('status_code=200') ||
        lower.contains('status_code=201') ||
        lower.contains('transaction_status=settlement') ||
        lower.contains('transaction_status=capture');

    final isExpired = lower.contains('status_code=407') || lower.contains('transaction_status=expire');
    final isFailed = lower.contains('status_code=202') ||
        lower.contains('transaction_status=deny') ||
        lower.contains('transaction_status=cancel');

    if (!_hasNavigated && isSuccess) {
      _paymentProvider?.stopPolling();
      _navigateToSuccess();
      return;
    }

    if (!_hasNavigated && (isExpired || isFailed)) {
      _paymentProvider?.stopPolling();
      if (mounted) {
        setState(() {
          _errorMessage = isExpired ? 'Payment expired' : 'Payment failed';
        });
      }
    }
  }

  @override
  void dispose() {
    _paymentProvider?.stopPolling();
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
        body: Consumer<PaymentProvider>(
          builder: (context, paymentProvider, _) {
            // Auto navigate to success if payment is successful
            if (paymentProvider.paymentStatus != null &&
                !_hasNavigated &&
                paymentProvider.paymentStatus!.isPaid) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_hasNavigated) {
                  _navigateToSuccess();
                }
              });
            }

            final paymentStatus = paymentProvider.paymentStatus;

            // Success state - navigate to success screen
            if (paymentStatus != null && paymentStatus.isPaid) {
              return _buildLoadingState('Menyiapkan halaman sukses...');
            }

            // Failed state
            if (paymentStatus != null && paymentStatus.isFailed) {
              return _buildFailedState();
            }

            // Expired state
            if (paymentStatus != null && paymentStatus.isExpired) {
              return _buildExpiredState();
            }

            // Loading state
            if (_isLoadingSnapToken) {
              return _buildLoadingState('Menyiapkan pembayaran...');
            }

            // Error state
            if (_errorMessage != null && _snapToken == null) {
              return _buildErrorState(_errorMessage!);
            }

            // Pending state: Show WebView
            return _buildPaymentState(paymentProvider);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error Pembayaran',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoadingSnapToken = true;
                  _hasNavigated = false;
                });
                _initializePayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Coba Lagi'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentState(PaymentProvider paymentProvider) {
    return Stack(
      children: [
        // WebView
        if (_webViewController != null)
          WebViewWidget(controller: _webViewController!)
        else
          _buildLoadingState('Memuat halaman pembayaran...'),

        // Loading overlay
        if (_isWebViewLoading)
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

        // Payment status indicator
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildPaymentStatusIndicator(paymentProvider),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusIndicator(PaymentProvider paymentProvider) {
    final isPolling = paymentProvider.isPolling;
    final paymentStatus = paymentProvider.paymentStatus;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPolling && (paymentStatus == null || paymentStatus.isPending))
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Menunggu konfirmasi pembayaran...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Pesanan: ${widget.orderNumber}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pembayaran Gagal',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pembayaran Anda tidak dapat diproses.\nSilakan coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoadingSnapToken = true;
                  _hasNavigated = false;
                });
                _initializePayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Coba Lagi'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time,
                size: 64,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pembayaran Kedaluwarsa',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sesi pembayaran telah kedaluwarsa.\nSilakan buat pembayaran baru.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoadingSnapToken = true;
                  _hasNavigated = false;
                });
                _initializePayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Buat Pembayaran Baru'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
