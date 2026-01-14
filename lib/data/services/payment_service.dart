import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/dio_client.dart';
import '../models/api_response_model.dart';

class PaymentService {
  final Dio _dio = DioClient().dio;
  Timer? _pollingTimer;

  /// Generate Snap Token untuk Midtrans payment
  Future<String> generateSnapToken(String orderNumber) async {
    try {
      final response = await _dio.post(
        ApiConstants.paymentSnapToken,
        data: {'order_number': orderNumber},
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data['snap_token'] as String;
      } else {
        throw Exception(data['message'] ?? 'Failed to generate snap token');
      }
    } on DioException catch (e) {
      throw Exception(DioClient.getErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to generate snap token: $e');
    }
  }

  /// Check payment status dan auto-update database
  Future<Map<String, dynamic>> checkPaymentStatus(String orderNumber) async {
    try {
      final response = await _dio.post(
        ApiConstants.paymentCheckStatus,
        data: {'order_number': orderNumber},
      );

      final data = response.data as Map<String, dynamic>;
      return {
        'success': true,
        'payment_status': data['payment_status'] as String? ?? 'pending',
        'order_status': data['order_status'] as String? ?? 'new',
        'transaction_status': data['transaction_status'] as String?,
        'status_updated': data['status_updated'] as bool? ?? false,
        'message': data['message'] as String? ?? '',
      };
    } on DioException catch (e) {
      throw Exception(DioClient.getErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to check payment status: $e');
    }
  }

  /// Start polling payment status (auto-update setiap 5 detik)
  void startPaymentStatusPolling(
    String orderNumber, {
    required Function(String status) onStatusUpdate,
    int maxAttempts = 20,
  }) {
    int attempts = 0;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;

      // Stop jika sudah max attempts (100 detik)
      if (attempts > maxAttempts) {
        timer.cancel();
        _pollingTimer = null;
        return;
      }

      try {
        final result = await checkPaymentStatus(orderNumber);
        final paymentStatus = result['payment_status'] as String;
        final statusUpdated = result['status_updated'] as bool;

        // Callback untuk update UI
        onStatusUpdate(paymentStatus);

        // Stop polling jika status sudah final
        if (paymentStatus == 'paid' ||
            paymentStatus == 'failed' ||
            paymentStatus == 'expired') {
          timer.cancel();
          _pollingTimer = null;
        }
      } catch (e) {
        // Continue polling on error
        print('Error polling payment status: $e');
      }
    });
  }

  /// Stop polling
  void stopPaymentStatusPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void dispose() {
    stopPaymentStatusPolling();
  }
}

