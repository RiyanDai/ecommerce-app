class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://10.0.2.2:8000/api';
  // For iOS/real device you can switch to:
  // static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Auth
  static const String login = '$baseUrl/login';
  static const String register = '$baseUrl/register';
  static const String logout = '$baseUrl/logout';
  static const String currentUser = '$baseUrl/user';

  // Products & Categories
  static const String products = '$baseUrl/products';
  static String productDetail(int id) => '$baseUrl/products/$id';
  static const String categories = '$baseUrl/categories';

  // Cart
  static const String cart = '$baseUrl/cart';
  static String cartItem(int id) => '$baseUrl/cart/$id';

  // Checkout & Orders
  static const String checkout = '$baseUrl/checkout';
  static const String orders = '$baseUrl/orders';
  static String orderDetail(int id) => '$baseUrl/orders/$id';
  static String cancelOrder(int id) => '$baseUrl/orders/$id/cancel';

  // Payment
  static const String paymentSnapToken = '$baseUrl/payment/snap-token';
  static const String paymentCheckStatus = '$baseUrl/payment/check-status';
}


