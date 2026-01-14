import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/dio_client.dart';
import '../models/api_response_model.dart';

class OrderService {
  final Dio _dio = DioClient().dio;

  Future<ApiResponse> checkout() async {
    try {
      // New API: empty body, cart items are used automatically
      final response = await _dio.post(
        ApiConstants.checkout,
        data: {},
      );
      return ApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: DioClient.getErrorMessage(e),
        data: null,
        errors: e.response?.data,
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        message: 'Unexpected error. Please try again.',
        data: null,
        errors: null,
      );
    }
  }

  Future<ApiResponse> getOrders() async {
    try {
      final response = await _dio.get(ApiConstants.orders);
      return ApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: DioClient.getErrorMessage(e),
        data: null,
        errors: e.response?.data,
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        message: 'Unexpected error. Please try again.',
        data: null,
        errors: null,
      );
    }
  }

  Future<ApiResponse> getOrderDetail(int orderId) async {
    try {
      final response = await _dio.get(ApiConstants.orderDetail(orderId));
      return ApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: DioClient.getErrorMessage(e),
        data: null,
        errors: e.response?.data,
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        message: 'Unexpected error. Please try again.',
        data: null,
        errors: null,
      );
    }
  }

  Future<ApiResponse> cancelOrder(int orderId) async {
    try {
      final response = await _dio.post(ApiConstants.cancelOrder(orderId));
      return ApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: DioClient.getErrorMessage(e),
        data: null,
        errors: e.response?.data,
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        message: 'Unexpected error. Please try again.',
        data: null,
        errors: null,
      );
    }
  }
}


