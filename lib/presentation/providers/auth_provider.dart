import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/utils/storage_helper.dart';
import '../../data/models/user_model.dart';
import '../../data/models/api_response_model.dart';
import '../../data/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> checkLoginStatus() async {
    _setLoading(true);
    try {
      final loggedIn = await StorageHelper.isLoggedIn();
      if (loggedIn) {
        await loadUser();
      }
      return loggedIn;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUser() async {
    try {
      final user = await StorageHelper.getUser();
      _currentUser = user;
      _notifySafe();
    } catch (_) {
      // ignore
    }
  }

  Future<ApiResponse> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _authService.login(email, password);
      if (response.success) {
        final data = response.data as Map<String, dynamic>? ?? {};
        final token = data['token']?.toString();
        final userJson = data['user'] as Map<String, dynamic>? ?? {};
        final user = UserModel.fromJson(userJson);

        if (token != null) {
          await StorageHelper.saveToken(token);
        }
        await StorageHelper.saveUser(user);
        _currentUser = user;
        _notifySafe();
      } else {
        _setError(response.message);
      }
      return response;
    } catch (e) {
      final res = ApiResponse(
        success: false,
        message: 'Login failed. Please try again.',
        data: null,
        errors: null,
      );
      _setError(res.message);
      return res;
    } finally {
      _setLoading(false);
    }
  }

  Future<ApiResponse> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final response =
          await _authService.register(name, email, password, passwordConfirmation);
      if (!response.success) {
        _setError(response.message);
      }
      return response;
    } catch (_) {
      final res = ApiResponse(
        success: false,
        message: 'Registration failed. Please try again.',
        data: null,
        errors: null,
      );
      _setError(res.message);
      return res;
    } finally {
      _setLoading(false);
    }
  }

  Future<ApiResponse> logout() async {
    _setLoading(true);
    try {
      final response = await _authService.logout();
      await StorageHelper.removeToken();
      await StorageHelper.removeUser();
      _currentUser = null;
      _notifySafe();
      return response;
    } catch (_) {
      return ApiResponse(
        success: false,
        message: 'Logout failed. Please try again.',
        data: null,
        errors: null,
      );
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _notifySafe();
  }

  void _setError(String? message) {
    _errorMessage = message;
    _notifySafe();
  }

  void _notifySafe() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }
}


