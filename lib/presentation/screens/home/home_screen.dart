import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/product_model.dart';
import '../../../data/models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';
import '../order/order_list_screen.dart';
import '../product/product_detail_screen.dart';
import '../../widgets/app_bottom_navigation_bar.dart';

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
  final PageController _bannerPageController = PageController();
  int _currentBannerIndex = 0;

  // Mock banner data - can be replaced with API data
  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Special Offer',
      'subtitle': 'Get up to 50% off on selected items',
      'buttonText': 'Shop Now',
    },
    {
      'title': 'New Arrivals',
      'subtitle': 'Discover the latest products',
      'buttonText': 'Explore',
    },
    {
      'title': 'Flash Sale',
      'subtitle': 'Limited time deals you don\'t want to miss',
      'buttonText': 'Buy Now',
    },
  ];

  // Category color palette
  final List<Color> _categoryColors = [
    const Color(0xFF2F54EB), // Blue
    const Color(0xFFFF1493), // Pink
    const Color(0xFFFF8C00), // Orange
    const Color(0xFF9370DB), // Purple
    const Color(0xFF32CD32), // Green
    const Color(0xFF20B2AA), // Teal
  ];

  // Category icon mapping
  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('electronic') || name.contains('elektronik')) {
      return Icons.laptop;
    } else if (name.contains('fashion') || name.contains('pakaian')) {
      return Icons.checkroom;
    } else if (name.contains('food') || name.contains('makanan')) {
      return Icons.restaurant;
    } else if (name.contains('beauty') || name.contains('kecantikan')) {
      return Icons.spa;
    } else if (name.contains('sport') || name.contains('olahraga')) {
      return Icons.sports_soccer;
    } else if (name.contains('book') || name.contains('buku')) {
      return Icons.book;
    } else {
      return Icons.category;
    }
  }

  Color _getCategoryColor(int index) {
    return _categoryColors[index % _categoryColors.length];
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final productProvider = context.read<ProductProvider>();
      productProvider.fetchCategories();
      productProvider.fetchProducts(refresh: true);
      context.read<CartProvider>().fetchCart();
      context.read<OrderProvider>().fetchOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<ProductProvider>().fetchProducts(refresh: true);
    await context.read<CartProvider>().fetchCart();
  }


  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cartProvider = context.watch<CartProvider>();
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.currentUser?.name ?? 'User';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              // Top Header
              SliverToBoxAdapter(
                child: _buildHeader(context, username, cartProvider),
              ),
              // Search Bar
              SliverToBoxAdapter(
                child: _buildSearchBar(context, productProvider),
              ),
              // Hero Banner
              SliverToBoxAdapter(
                child: _buildHeroBanner(context),
              ),
              // Categories Section
              SliverToBoxAdapter(
                child: _buildCategoriesSection(context, productProvider),
              ),
              // Featured Products Section
              SliverToBoxAdapter(
                child: _buildFeaturedProductsHeader(context),
              ),
              // Products Grid
              if (productProvider.isLoading && productProvider.products.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (productProvider.errorMessage != null &&
                  productProvider.errorMessage!.isNotEmpty &&
                  productProvider.products.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(productProvider.errorMessage!),
                  ),
                )
              else if (productProvider.products.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No products found')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = productProvider.products[index];
                        return _FeaturedProductCard(
                          product: product,
                          currency: _currency,
                        );
                      },
                      childCount: productProvider.products.length,
                    ),
                  ),
                ),
              // Load More Button
              if (productProvider.hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Load More'),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80), // Space for bottom nav
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 0),
    );
  }

  Widget _buildHeader(
      BuildContext context, String username, CartProvider cartProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hi, $username!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Cart Icon with Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(CartScreen.routeName);
                },
              ),
              if (cartProvider.itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 255, 0, 0),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        cartProvider.itemCount > 99
                            ? '99+'
                            : cartProvider.itemCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
      BuildContext context, ProductProvider productProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onSubmitted: (value) {
            productProvider.searchProducts(value);
          },
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _bannerPageController,
              onPageChanged: (index) {
                setState(() {
                  _currentBannerIndex = index;
                });
              },
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.blue,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        banner['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banner['subtitle'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate or perform action
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2F54EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                        ),
                        child: Text(banner['buttonText'] as String),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_banners.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _banners.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentBannerIndex == index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentBannerIndex == index
                          ? const Color(0xFF2F54EB)
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(
      BuildContext context, ProductProvider productProvider) {
    if (productProvider.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            'Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: productProvider.categories.length + 1, // +1 for "All" option
            itemBuilder: (context, index) {
              // "All" option
              if (index == 0) {
                final isSelected = productProvider.selectedCategoryId == null;
                return GestureDetector(
                  onTap: () {
                    productProvider.filterByCategory(null);
                  },
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2F54EB)
                                : Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2F54EB)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.apps,
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF2F54EB)
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Category items
              final category = productProvider.categories[index - 1];
              final color = _getCategoryColor(index - 1);
              final icon = _getCategoryIcon(category.name);
              final isSelected = productProvider.selectedCategoryId == category.id;

              return GestureDetector(
                onTap: () {
                  productProvider.filterByCategory(category.id);
                },
                child: Container(
                  width: 80,
                  margin: EdgeInsets.only(
                    right: index == productProvider.categories.length ? 0 : 12,
                  ),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.white : color,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFeaturedProductsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Featured Products',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
           
        ],
      ),
    );
  }

}

class _FeaturedProductCard extends StatelessWidget {
  final ProductModel product;
  final NumberFormat currency;

  const _FeaturedProductCard({
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product Image
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: product.fullImageUrl != null
                        ? Image.network(
                            product.fullImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
                // Product Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: product.stock > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  product.stock > 0
                                      ? 'Stock: ${product.stock}'
                                      : 'Out of Stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: product.stock > 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          currency.format(product.price),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Add to Cart Button
            if (product.stock > 0)
              Positioned(
                bottom: 8,
                right: 8,
                child: Material(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: cartProvider.isLoading
                        ? null
                        : () async {
                            final ok = await cartProvider.addToCart(product, 1);
                            if (ok) {
                              Fluttertoast.showToast(
                                  msg: 'Added to cart successfully');
                            } else {
                              Fluttertoast.showToast(
                                  msg: 'Failed to add to cart');
                            }
                          },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: cartProvider.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
