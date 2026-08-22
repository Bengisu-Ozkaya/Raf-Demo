import 'product.dart';

/// Bir dükkanın oluşturduğu paketi temsil eden model sınıfı.
class ShopPackage {
  final int id;
  final int shopId;
  final String? shopName;
  final String? shopPhone;
  final String name;
  final String packageSize;
  final double totalPrice;
  final int stock;
  final int isActive;
  final DateTime? createdAt;
  final List<Product> items;

  ShopPackage({
    required this.id,
    required this.shopId,
    this.shopName,
    this.shopPhone,
    required this.name,
    required this.packageSize,
    required this.totalPrice,
    required this.stock,
    this.isActive = 1,
    this.createdAt,
    this.items = const [],
  });

  factory ShopPackage.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<Product> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems.map((item) {
        if (item is Map<String, dynamic>) {
          return Product.fromJson(item);
        }
        return Product.empty();
      }).toList();
    }

    return ShopPackage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      shopId: json['shop_id'] is int ? json['shop_id'] : int.tryParse(json['shop_id']?.toString() ?? '0') ?? 0,
      shopName: json['shop_name']?.toString(),
      shopPhone: json['shop_phone']?.toString() ?? json['phone']?.toString(),
      name: json['name'] ?? '',
      packageSize: json['package_size'] ?? 'Orta Boy',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] ?? 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      items: parsedItems,
    );
  }

  ShopPackage copyWith({
    int? id,
    int? shopId,
    String? shopName,
    String? shopPhone,
    String? name,
    String? packageSize,
    double? totalPrice,
    int? stock,
    int? isActive,
    DateTime? createdAt,
    List<Product>? items,
  }) {
    return ShopPackage(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      name: name ?? this.name,
      packageSize: packageSize ?? this.packageSize,
      totalPrice: totalPrice ?? this.totalPrice,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
