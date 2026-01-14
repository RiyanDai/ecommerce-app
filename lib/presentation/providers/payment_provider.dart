import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../data/models/payment_status_model.dart';
import '../../data/services/payment_service.dart';

/// Payment Provider
/// 
/// Manages payment state including:
/// - Generating Snap Token
/// - Checking Payment Status
/// - Polling Payment Status
class PaymentProvider extends ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  String? _snapToken;
  PaymentStatusModel? _paymentStatus;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPolling = false;
  Timer? _pollingTimer;

  // Getters
  String? get snapToken => _snapToken;
  PaymentStatusModel? get paymentStatus => _paymentStatus;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPolling => _isPolling;

  /// Generate Snap Token for Midtrans payment
  Future<bool> generateSnapToken(String orderNumber) async {
    _setLoading(true);
    _errorMessage = null;
    _snapToken = null;

    try {
      debugPrint('PaymentProvider: Generating snap token for order: $orderNumber');
      final token = await _paymentService.generateSnapToken(orderNumber);
      _snapToken = token;
      debugPrint('PaymentProvider: ✅ Snap token generated successfully');
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('PaymentProvider: ❌ Error generating snap token: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Check payment status and auto-update database
  Future<bool> checkPaymentStatus(String orderNumber) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      debugPrint('PaymentProvider: Checking payment status for order: $orderNumber');
      final result = await _paymentService.checkPaymentStatus(orderNumber);
      _paymentStatus = PaymentStatusModel.fromJson(result);
      debugPrint('PaymentProvider: ✅ Payment status: ${_paymentStatus!.paymentStatus}');
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('PaymentProvider: ❌ Error checking payment status: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Start polling payment status (auto-update every 5 seconds)
  void startPolling(String orderNumber, {int maxAttempts = 60}) {
    if (_isPolling) {
      debugPrint('PaymentProvider: Already polling, skipping...');
      return;
    }

    debugPrint('PaymentProvider: Starting payment status polling...');
    _isPolling = true;
    _notifySafe();

    int attempts = 0;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;

      debugPrint('PaymentProvider: Polling attempt $attempts/$maxAttempts');

      // Stop if max attempts reached
      if (attempts > maxAttempts) {
        debugPrint('PaymentProvider: Max polling attempts reached, stopping...');
        timer.cancel();
        _isPolling = false;
        _pollingTimer = null;
        notifyListeners();
        return;
      }

      try {
        final result = await _paymentService.checkPaymentStatus(orderNumber);
        final status = PaymentStatusModel.fromJson(result);

        // Update payment status
        _paymentStatus = status;
        _notifySafe();

        debugPrint('PaymentProvider: Polling result - Status: ${status.paymentStatus}, Updated: ${status.statusUpdated}');

        // Stop polling if status is final
        if (status.isFinal) {
          debugPrint('PaymentProvider: Final status reached (${status.paymentStatus}), stopping polling...');
          timer.cancel();
          _isPolling = false;
          _pollingTimer = null;
          _notifySafe();
        }
      } catch (e) {
        debugPrint('PaymentProvider: Error during polling: $e');
        // Continue polling on error
      }
    });
  }

  /// Stop polling
  void stopPolling() {
    debugPrint('PaymentProvider: Stopping payment status polling...');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _notifySafe();
  }

  /// Clear payment data
  void clearPaymentData() {
    _snapToken = null;
    _paymentStatus = null;
    _errorMessage = null;
    _isLoading = false;
    stopPolling();
    _notifySafe();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _notifySafe();
  }

  /// Avoid calling notifyListeners when the widget tree is locked (e.g. during
  /// build/layout), which can trigger FlutterError. If the scheduler is busy,
  /// defer the notification to the next frame.
  void _notifySafe() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  @override
  void dispose() {
    stopPolling();
    _paymentService.dispose();
    super.dispose();
  }
}
