import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/dio_client.dart';
import '../models/api_response_model.dart';

class CartService {
  final Dio _dio = DioClient().dio;

  Future<ApiResponse> getCart() async {
    try {
      final response = await _dio.get(ApiConstants.cart);
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

  Future<ApiResponse> addToCart(int productId, int quantity) async {
    try {
      final response = await _dio.post(
        ApiConstants.cart,
        data: {
          'product_id': productId,
          'quantity': quantity,
        },
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

  Future<ApiResponse> updateCart(int cartId, int quantity) async {
    try {
      final response = await _dio.put(
        ApiConstants.cartItem(cartId),
        data: {'quantity': quantity},
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

  Future<ApiResponse> removeFromCart(int cartId) async {
    try {
      final response = await _dio.delete(ApiConstants.cartItem(cartId));
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


