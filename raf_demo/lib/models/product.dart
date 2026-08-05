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

  Product({
    required this.id,
    required this.shopId,
    // masterProductId, name, imageUrl, category, brand, weightVolume alanları
    // master_products'tan veya shop_products'tan gelebilir.
    required this.masterProductId,
    required this.name,
    this.price, // Nullable olduğu için required kaldırıldı
    this.stock, // Nullable olduğu için required kaldırıldı
    this.imageUrl,
    this.category,
    this.brand,
    this.weightVolume,
  });

  /// JSON verisinden bir Product nesnesi oluşturur.
  /// Backend'den gelen snake_case (örn: shop_id) anahtarları
  /// modeldeki camelCase (örn: shopId) alanlarla eşleştirir.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      shopId: json['shop_id'] ?? 0, // shop_products'tan geliyorsa
      masterProductId: json['master_product_id'] ??
          json['id'], // master_products'tan geliyorsa kendi ID'si
      name: json['product_name'] ??
          json[
              'name'], // master_products'tan geliyorsa product_name, shop_products'tan geliyorsa name
      price: (json['price'] as num?)?.toDouble(), // Null kontrolü eklendi
      stock: json['stock'] as int?, // Null kontrolü eklendi
      imageUrl: json['image_url'],
      category: json['category'],
      brand: json['brand'],
      weightVolume: json['weight_volume'],
    );
  }

  /// Boş bir Product nesnesi döndürür. Özellikle `orElse` durumlarında kullanılır.
  factory Product.empty() {
    return Product(
      id: 0,
      shopId: 0,
      masterProductId: 0,
      name: '',
      price: null, // Nullable olduğu için varsayılan değer null
      stock: null, // Nullable olduğu için varsayılan değer null
      imageUrl: null,
      category: null,
      brand: null,
      weightVolume: null,
    );
  }

  /// Nesnenin kopyasını oluştururken belirtilen alanları güncelleyen
  /// ve state'in immutable (değişmez) kalmasını sağlayan yardımcı metod.
  Product copyWith({
    int? id,
    int? shopId,
    String? name,
    double? price, // Nullable olarak güncellendi
    int? stock, // Nullable olarak güncellendi
    String? imageUrl,
    String? category,
    String? brand,
    String? weightVolume,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      masterProductId: masterProductId ?? masterProductId,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      weightVolume: weightVolume ?? this.weightVolume,
    );
  }
}
