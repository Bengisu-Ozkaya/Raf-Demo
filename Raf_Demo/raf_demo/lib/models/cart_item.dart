import 'product.dart';
import 'shop_package.dart';

/// Sepetteki tek bir ürün veya paket grubunu temsil eder.
class CartItem {
  final int id; // Ürünün ID'si veya Paketin Negatif ID'si
  final String name;
  final double price;
  final String? imageUrl;
  final String? weightVolume;
  int quantity;
  final bool isPackage;
  final String? packageSize;
  final int? packageItemCount;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.weightVolume,
    required this.quantity,
    this.isPackage = false,
    this.packageSize,
    this.packageItemCount,
  });

  /// Bir Product nesnesinden CartItem oluşturur.
  factory CartItem.fromProduct(Product product, {int quantity = 1}) {
    return CartItem(
      id: product.id,
      name: product.name,
      price: product.price ?? product.unitPrice ?? 0.0,
      imageUrl: product.imageUrl,
      weightVolume: product.weightVolume,
      quantity: quantity,
      isPackage: false,
    );
  }

  /// Bir ShopPackage nesnesinden CartItem oluşturur.
  factory CartItem.fromPackage(ShopPackage package, {int quantity = 1}) {
    return CartItem(
      id: -package.id, // Paketler için negatif ID
      name: package.name,
      price: package.totalPrice,
      imageUrl: package.items.isNotEmpty ? package.items.first.imageUrl : null,
      quantity: quantity,
      isPackage: true,
      packageSize: package.packageSize,
      packageItemCount: package.items.length,
    );
  }

  /// Sepetteki ürün miktarını artırır.
  void increment() {
    quantity++;
  }

  /// Sepetteki ürün miktarını azaltır.
  void decrement() {
    if (quantity > 0) {
      quantity--;
    }
  }

  /// Bu CartItem'ın toplam fiyatını hesaplar.
  double get totalPrice => price * quantity;

  /// SharedPreferences'da saklamak için JSON'a dönüştürür.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'weightVolume': weightVolume,
      'quantity': quantity,
      'isPackage': isPackage,
      'packageSize': packageSize,
      'packageItemCount': packageItemCount,
    };
  }

  /// SharedPreferences'dan okumak için JSON'dan oluşturur.
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'],
      weightVolume: json['weightVolume'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      isPackage: json['isPackage'] as bool? ?? false,
      packageSize: json['packageSize'] as String?,
      packageItemCount: json['packageItemCount'] as int?,
    );
  }
}
