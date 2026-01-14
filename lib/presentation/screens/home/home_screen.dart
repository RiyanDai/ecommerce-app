import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';
import '../order/order_list_screen.dart';
import '../product/product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final productProvider = context.read<ProductProvider>();
      productProvider.fetchCategories();
      productProvider.fetchProducts(refresh: true);
      context.read<CartProvider>().fetchCart();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<ProductProvider>().fetchProducts(refresh: true);
    await context.read<CartProvider>().fetchCart();
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cartProvider = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Commerce'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.of(context).pushNamed(OrderListScreen.routeName);
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.of(context).pushNamed(CartScreen.routeName);
                },
              ),
              if (cartProvider.itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      cartProvider.itemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    productProvider.searchProducts(_searchController.text);
                  },
                ),
              ),
              onSubmitted: (value) {
                productProvider.searchProducts(value);
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: productProvider.selectedCategoryId == null,
                  onSelected: (_) =>
                      productProvider.filterByCategory(null),
                ),
                ...productProvider.categories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(cat.name),
                      selected:
                          productProvider.selectedCategoryId == cat.id,
                      onSelected: (_) =>
                          productProvider.filterByCategory(cat.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: Builder(
                builder: (context) {
                  if (productProvider.isLoading &&
                      productProvider.products.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (productProvider.errorMessage != null &&
                      productProvider.errorMessage!.isNotEmpty &&
                      productProvider.products.isEmpty) {
                    return Center(
                      child: Text(productProvider.errorMessage!),
                    );
                  }
                  if (productProvider.products.isEmpty) {
                    return const Center(
                      child: Text('No products found'),
                    );
                  }

                  final products = productProvider.products;
                  return Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.66,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _ProductCard(
                              product: product,
                              currency: _currency,
                            );
                          },
                        ),
                      ),
                      if (productProvider.hasMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ElevatedButton(
                            onPressed: productProvider.isLoading
                                ? null
                                : () {
                                    productProvider.fetchProducts();
                                  },
                            child: productProvider.isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Load More'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final NumberFormat currency;

  const _ProductCard({
    required this.product,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();

    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          ProductDetailScreen.routeName,
          arguments: product.id,
        );
      },
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: product.fullImageUrl != null
                  ? Image.network(
                      product.fullImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported,
                        size: 48,
                      ),
                    )
                  : const Icon(
                      Icons.image,
                      size: 48,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(product.price),
                    style: const TextStyle(color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${product.stock}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: cartProvider.isLoading
                          ? null
                          : () async {
                              final ok =
                                  await cartProvider.addToCart(product, 1);
                              if (ok) {
                                Fluttertoast.showToast(
                                    msg: 'Added to cart successfully');
                              } else {
                                Fluttertoast.showToast(
                                    msg: 'Failed to add to cart');
                              }
                            },
                      child: cartProvider.isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Add to Cart',
                              style: TextStyle(fontSize: 12),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


