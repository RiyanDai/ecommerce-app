import '../../core/constants/api_constants.dart';

class ProductModel {
  final int id;
  final int? categoryId;
  final String name;
  final String slug;
  final String? description;
  final double price;
  final int stock;
  final String? image;
  final String? imageUrl;
  final bool isActive;

  ProductModel({
    required this.id,
    this.categoryId,
    required this.name,
    required this.slug,
    this.description,
    required this.price,
    required this.stock,
    this.image,
    this.imageUrl,
    required this.isActive,
  });

  /// Helper untuk membentuk URL gambar penuh dari berbagai kemungkinan field.
  String? get fullImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl;
    }
    if (image == null || image!.isEmpty) return null;

    final value = image!;
    if (value.startsWith('http')) {
      return value;
    }

    // Ambil host dari baseUrl (hapus suffix /api kalau ada)
    final base = ApiConstants.baseUrl.endsWith('/api')
        ? ApiConstants.baseUrl.substring(
            0, ApiConstants.baseUrl.length - '/api'.length)
        : ApiConstants.baseUrl;

    if (value.startsWith('/')) {
      return '$base$value';
    }
    return '$base/$value';
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '0') ?? 0.0;
    }

    return ProductModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      categoryId: json['category_id'] is int
          ? json['category_id'] as int
          : int.tryParse('${json['category_id']}'),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description']?.toString(),
      price: parsePrice(json['price']),
      stock: json['stock'] is int
          ? json['stock'] as int
          : int.tryParse('${json['stock']}') ?? 0,
      image: json['image']?.toString(),
      imageUrl: json['image_url']?.toString(),
      isActive: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['is_active']?.toString() == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      'stock': stock,
      'image': image,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }
}


