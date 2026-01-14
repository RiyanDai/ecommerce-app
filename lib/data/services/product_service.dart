import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/dio_client.dart';
import '../models/api_response_model.dart';

class ProductService {
  final Dio _dio = DioClient().dio;

  Future<ApiResponse> getProducts({
    String? search,
    int? categoryId,
    int? page,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }
      if (categoryId != null) {
        queryParameters['category_id'] = categoryId;
      }
      if (page != null) {
        queryParameters['page'] = page;
      }

      final response = await _dio.get(
        ApiConstants.products,
        queryParameters: queryParameters,
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

  Future<ApiResponse> getProductDetail(int id) async {
    try {
      final response = await _dio.get(ApiConstants.productDetail(id));
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

  Future<ApiResponse> getCategories() async {
    try {
      final response = await _dio.get(ApiConstants.categories);
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


