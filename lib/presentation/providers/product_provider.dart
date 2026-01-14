import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();

  final List<ProductModel> _products = [];
  final List<CategoryModel> _categories = [];
  ProductModel? _selectedProduct;
  bool _isLoading = false;
  String? _errorMessage;

  int _currentPage = 1;
  bool _hasMore = true;
  String? _search;
  int? _selectedCategoryId;

  List<ProductModel> get products => List.unmodifiable(_products);
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  ProductModel? get selectedProduct => _selectedProduct;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  int? get selectedCategoryId => _selectedCategoryId;
  String? get search => _search;

  Future<void> fetchCategories() async {
    try {
      final response = await _productService.getCategories();
      if (response.success) {
        _categories.clear();
        final data = response.data;
        if (data is List) {
          _categories.addAll(
            data
                .whereType<Map<String, dynamic>>()
                .map((e) => CategoryModel.fromJson(e))
                .toList(),
          );
        }
        _notifySafe();
      }
    } catch (_) {
      // swallow errors for categories; not critical
    }
  }

  Future<void> fetchProducts({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    _setLoading(true);
    _setError(null);

    try {
      if (refresh) {
        _currentPage = 1;
        _hasMore = true;
        _products.clear();
      }

      final response = await _productService.getProducts(
        search: _search,
        categoryId: _selectedCategoryId,
        page: _currentPage,
      );

      if (response.success) {
        final data = response.data;
        final List<ProductModel> fetched = [];

        if (data is Map<String, dynamic> && data['data'] is List) {
          // Laravel pagination: data: { data: [ ... ] }
          for (final item in data['data'] as List) {
            if (item is Map<String, dynamic>) {
              fetched.add(ProductModel.fromJson(item));
            }
          }
          // detect next page
          _hasMore = (data['next_page_url'] != null);
        } else if (data is List) {
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              fetched.add(ProductModel.fromJson(item));
            }
          }
          _hasMore = fetched.isNotEmpty;
        }

        _products.addAll(fetched);
        if (fetched.isNotEmpty) {
          _currentPage += 1;
        }
        _notifySafe();
      } else {
        _setError(response.message);
      }
    } catch (_) {
      _setError('Failed to load products.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchProductDetail(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _productService.getProductDetail(id);
      if (response.success && response.data is Map<String, dynamic>) {
        _selectedProduct =
            ProductModel.fromJson(response.data as Map<String, dynamic>);
        _notifySafe();
      } else {
        _setError(response.message);
      }
    } catch (_) {
      _setError('Failed to load product detail.');
    } finally {
      _setLoading(false);
    }
  }

  void searchProducts(String? search) {
    _search = search;
    fetchProducts(refresh: true);
  }

  void filterByCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    fetchProducts(refresh: true);
  }

  void clearSelectedProduct() {
    _selectedProduct = null;
    _notifySafe();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _notifySafe();
  }

  void _setError(String? value) {
    _errorMessage = value;
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


