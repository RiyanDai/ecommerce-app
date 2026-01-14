import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/dio_client.dart';
import '../models/api_response_model.dart';

class AuthService {
  final Dio _dio = DioClient().dio;

  Future<ApiResponse> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
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

  Future<ApiResponse> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
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

  Future<ApiResponse> logout() async {
    try {
      final response = await _dio.post(ApiConstants.logout);
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

  Future<ApiResponse> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConstants.currentUser);
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


