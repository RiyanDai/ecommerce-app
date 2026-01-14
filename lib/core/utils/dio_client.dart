import 'dart:io';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import 'storage_helper.dart';

class DioClient {
  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: {
          HttpHeaders.acceptHeader: 'application/json',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await StorageHelper.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers[HttpHeaders.authorizationHeader] =
                  'Bearer $token';
            }
          } catch (_) {
            // ignore token errors; request will proceed without auth header
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Let services interpret the error, but normalize timeouts & network
          return handler.next(e);
        },
      ),
    );
  }

  static final DioClient _instance = DioClient._internal();

  factory DioClient() => _instance;

  late final Dio dio;

  static String getErrorMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please try again.';
    }

    if (error.type == DioExceptionType.unknown &&
        error.error is SocketException) {
      return 'No internet connection. Please check your network.';
    }

    final response = error.response;
    if (response != null) {
      if (response.statusCode == 401) {
        return 'Unauthorized. Please login again.';
      } else if (response.statusCode != null &&
          response.statusCode! >= 500) {
        return 'Server error. Please try again later.';
      }

      try {
        final data = response.data;
        if (data is Map<String, dynamic> && data['message'] is String) {
          return data['message'] as String;
        }
      } catch (_) {
        // ignore parsing issues, fall through to generic message
      }
    }

    return 'Unexpected error occurred. Please try again.';
  }
}


