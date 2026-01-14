import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/payment_provider.dart';
import '../../providers/order_provider.dart';
import '../home/home_screen.dart';

/// Payment WebView Screen
/// 
/// Displays Midtrans Snap payment page in WebView and handles payment flow:
/// 1. Generate snap token from backend
/// 2. Load Midtrans Snap URL in WebView
/// 3. Poll backend to check payment status
/// 4. Navigate to home when payment is complete
class PaymentWebViewScreen extends StatefulWidget {
  static const String routeName = '/payment-webview';
  
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
  String? _currentUrl;
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
    _paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
  }

  Future<void> _initializePayment() async {
    if (!mounted) return;

    debugPrint('=== PaymentWebViewScreen: Initialize Payment ===');
    debugPrint('PaymentWebViewScreen: Order Number: ${widget.orderNumber}');

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
      debugPrint('PaymentWebViewScreen: Requesting snap token...');
      final success = await paymentProvider.generateSnapToken(widget.orderNumber);

      if (success && paymentProvider.snapToken != null) {
        _snapToken = paymentProvider.snapToken;
        debugPrint('PaymentWebViewScreen: ✅ Snap token received');

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
    } catch (e, stackTrace) {
      debugPrint('PaymentWebViewScreen: ❌ Error: $e');
      debugPrint('PaymentWebViewScreen: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingSnapToken = false;
          _errorMessage = 'Error initializing payment: $e';
        });
      }
    }
  }

  Future<void> _initializeWebView() async {
    if (_snapToken == null) {
      debugPrint('PaymentWebViewScreen: ❌ Cannot initialize WebView - snap token is null');
      return;
    }

    final snapUrl = '$_midtransBaseUrl/snap/v2/vtweb/$_snapToken';
    debugPrint('PaymentWebViewScreen: Opening Snap URL: $snapUrl');

    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('PaymentWebViewScreen: WebView page started: $url');
              _handleUrlSideEffects(url);
              if (mounted) {
                setState(() {
                  _isWebViewLoading = true;
                  _currentUrl = url;
                });
              }
            },
            onPageFinished: (String url) {
              debugPrint('PaymentWebViewScreen: WebView page finished: $url');
              _handleUrlSideEffects(url);
              if (mounted) {
                setState(() {
                  _isWebViewLoading = false;
                  _currentUrl = url;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('PaymentWebViewScreen: WebView error: ${error.description}');
              if (mounted) {
                setState(() {
                  _isWebViewLoading = false;
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              debugPrint('PaymentWebViewScreen: Navigation request: ${request.url}');
              _handleUrlSideEffects(request.url);
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(snapUrl));

      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      debugPrint('PaymentWebViewScreen: ❌ Error initializing WebView: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load payment page: $e';
          _isLoadingSnapToken = false;
        });
      }
    }
  }

  void _navigateToHome() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    debugPrint('PaymentWebViewScreen: Navigating to home...');

    Future.microtask(() {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          // Stop polling to prevent further UI updates after navigation
          _paymentProvider?.stopPolling();

          // Refresh orders before navigating
          Provider.of<OrderProvider>(context, listen: false).fetchOrders();
        } catch (e) {
          debugPrint('PaymentWebViewScreen: Error refreshing orders: $e');
        }

        // Navigate to home and clear all previous routes
        Navigator.of(context).pushNamedAndRemoveUntil(
          HomeScreen.routeName, // Home route
          (route) => false, // Remove all previous routes
        );
      });
    });
  }

  /// Midtrans sometimes redirects with status parameters before webhook/polling updates.
  /// Detect success/failed from URL hints to avoid waiting forever.
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
      debugPrint('PaymentWebViewScreen: Detected success from URL, navigating home.');
      _paymentProvider?.stopPolling();
      _navigateToHome();
      return;
    }

    if (!_hasNavigated && (isExpired || isFailed)) {
      debugPrint('PaymentWebViewScreen: Detected failure/expired from URL.');
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
        // Confirm before going back during payment
        if (!_hasNavigated) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel Payment?'),
              content: const Text('Are you sure you want to cancel this payment?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Consumer<PaymentProvider>(
          builder: (context, paymentProvider, _) {
            // Auto navigate to home if payment is successful
            if (paymentProvider.paymentStatus != null &&
                !_hasNavigated &&
                paymentProvider.paymentStatus!.isPaid) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_hasNavigated) {
                  _navigateToHome();
                }
              });
            }

            final paymentStatus = paymentProvider.paymentStatus;

            // Success state
            if (paymentStatus != null && paymentStatus.isPaid) {
              return _buildSuccessState();
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
              return _buildLoadingState('Preparing payment...');
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
            style: const TextStyle(fontSize: 16, color: Colors.grey),
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
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
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
          _buildLoadingState('Initializing payment page...'),

        // Loading overlay
        if (_isWebViewLoading)
          Container(
            color: Colors.white.withOpacity(0.8),
            child: const Center(
              child: CircularProgressIndicator(),
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
                const Text(
                  'Waiting for payment confirmation...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Order: ${widget.orderNumber}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
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
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your payment has been confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Redirecting to home...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
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
              'Payment Failed',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your payment could not be processed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
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
              'Payment Expired',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The payment session has expired.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Create New Payment'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}