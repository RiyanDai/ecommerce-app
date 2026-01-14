import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/themes/app_theme.dart';
 
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/cart_provider.dart';
import 'presentation/providers/order_provider.dart';
import 'presentation/providers/payment_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/cart/cart_screen.dart';
import 'presentation/screens/checkout/checkout_screen.dart';
import 'presentation/screens/payment/payment_screen.dart';
import 'presentation/screens/payment/payment_webview_screen.dart';
import 'presentation/screens/order/order_list_screen.dart';
import 'presentation/screens/order/order_detail_screen.dart';
import 'presentation/screens/product/product_detail_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ],
      child: MaterialApp(
        title: 'E-Commerce App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: SplashScreen.routeName,
        routes: {
          SplashScreen.routeName: (_) => const SplashScreen(),
          LoginScreen.routeName: (_) => const LoginScreen(),
          RegisterScreen.routeName: (_) => const RegisterScreen(),
          HomeScreen.routeName: (_) => const HomeScreen(),
          CartScreen.routeName: (_) => const CartScreen(),
          CheckoutScreen.routeName: (_) => const CheckoutScreen(),
          PaymentScreen.routeName: (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return PaymentScreen(
              orderNumber: args[PaymentScreen.argOrderNumber] as String,
              snapToken: args[PaymentScreen.argSnapToken] as String,
            );
          },
          OrderListScreen.routeName: (_) => const OrderListScreen(),
          OrderDetailScreen.routeName: (_) => const OrderDetailScreen(),
          ProductDetailScreen.routeName: (_) => const ProductDetailScreen(),
        },
      ),
    );
  }
}
