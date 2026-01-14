import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../cart/cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  static const String routeName = '/product-detail';

  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as int?;
    if (id != null) {
      context.read<ProductProvider>().fetchProductDetail(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cartProvider = context.watch<CartProvider>();
    final ProductModel? product = productProvider.selectedProduct;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Detail'),
      ),
      body: productProvider.isLoading && product == null
          ? const Center(child: CircularProgressIndicator())
          : product == null
              ? const Center(child: Text('Product not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 240,
                        width: double.infinity,
                        child: product.fullImageUrl != null
                            ? Image.network(
                                product.fullImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported,
                                  size: 64,
                                ),
                              )
                            : const Icon(
                                Icons.image,
                                size: 64,
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currency.format(product.price),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Stock: ${product.stock}'),
                      const SizedBox(height: 16),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(product.description ?? '-'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Quantity:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _quantity > 1
                                ? () {
                                    setState(() {
                                      _quantity--;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$_quantity'),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _quantity++;
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: cartProvider.isLoading
                                  ? null
                                  : () async {
                                      final ok = await cartProvider.addToCart(
                                          product, _quantity);
                                      if (ok) {
                                        Fluttertoast.showToast(
                                            msg: 'Added to cart');
                                      } else {
                                        Fluttertoast.showToast(
                                            msg: 'Failed to add to cart');
                                      }
                                    },
                              child: cartProvider.isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child:
                                          CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Add to Cart'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: cartProvider.isLoading
                                  ? null
                                  : () async {
                                      final ok = await cartProvider.addToCart(
                                          product, _quantity);
                                      if (ok && context.mounted) {
                                        Navigator.of(context).pushNamed(
                                            CartScreen.routeName);
                                      } else {
                                        Fluttertoast.showToast(
                                            msg: 'Failed to add to cart');
                                      }
                                    },
                              child: const Text('Buy Now'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}


