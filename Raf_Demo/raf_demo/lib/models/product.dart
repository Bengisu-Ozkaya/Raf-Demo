/// Bir ürünü temsil eden model sınıfı.
class Product {
  final int id;
  final int shopId;
  final int masterProductId; // YENİ: master_products tablosundaki ID
  final String name;
  final double? price; // Nullable yapıldı
  final int? stock; // Nullable yapıldı
  final String? imageUrl;
  final String? category;
  final String? brand; // YENİ: master_products'tan gelen marka
  final String? weightVolume; // YENİ: master_products'tan gelen ağırlık/hacim
  final double? unitPrice; // YENİ: PDF'ten gelen birim maliyet fiyatı
  final String? sapCode; // YENİ: PDF'ten gelen SAP kodu

  Product({
    required this.id,
    required this.shopId,
    required this.masterProductId,
    required this.name,
    this.price,
    this.stock,
    this.imageUrl,
    this.category,
    this.brand,
    this.weightVolume,
    this.unitPrice,
    this.sapCode,
  });

  /// JSON verisinden bir Product nesnesi oluşturur.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      shopId: json['shop_id'] is int ? json['shop_id'] : int.tryParse(json['shop_id']?.toString() ?? '0') ?? 0,
      masterProductId: json['master_product_id'] ?? json['id'],
      name: json['product_name'] ?? json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble(),
      stock: (json['stock'] as num?)?.toInt(),
      imageUrl: json['image_url'],
      category: json['category'],
      brand: json['brand'],
      weightVolume: json['weight_volume'],
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      sapCode: json['sap_code']?.toString(),
    );
  }

  /// Boş bir Product nesnesi döndürür.
  factory Product.empty() {
    return Product(
      id: 0,
      shopId: 0,
      masterProductId: 0,
      name: '',
      price: null,
      stock: null,
      imageUrl: null,
      category: null,
      brand: null,
      weightVolume: null,
      unitPrice: null,
      sapCode: null,
    );
  }

  /// Nesnenin kopyasını oluşturur.
  Product copyWith({
    int? id,
    int? shopId,
    int? masterProductId,
    String? name,
    double? price,
    int? stock,
    String? imageUrl,
    String? category,
    String? brand,
    String? weightVolume,
    double? unitPrice,
    String? sapCode,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      masterProductId: masterProductId ?? this.masterProductId,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      weightVolume: weightVolume ?? this.weightVolume,
      unitPrice: unitPrice ?? this.unitPrice,
      sapCode: sapCode ?? this.sapCode,
    );
  }
}
