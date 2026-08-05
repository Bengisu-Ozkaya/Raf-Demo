import 'product.dart';

/// Sepetteki tek bir ürün grubunu temsil eder (örn: 3 adet Elma).
class CartItem {
  final int id; // Ürünün ID'si
  final String name;
  final double
      price; // Sepete eklenen ürünün fiyatı null olmamalı, bu yüzden Product'tan gelirken kontrol edilecek.
  final String? imageUrl;
  int quantity; // Sepetteki miktar null olmamalı.

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.quantity,
  });

  /// Bir Product nesnesinden CartItem oluşturur.
  factory CartItem.fromProduct(Product product, {int quantity = 1}) {
    return CartItem(
      id: product.id,
      name: product.name,
      price: product.price ?? 0.0, // Null ise 0.0 ata
      imageUrl: product.imageUrl,
      quantity: quantity,
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
      'quantity': quantity,
    };
  }

  /// SharedPreferences'dan okumak için JSON'dan oluşturur.
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num?)?.toDouble() ??
          0.0, // Null gelirse 0.0 varsayılan değer
      imageUrl: json['imageUrl'],
      quantity:
          json['quantity'] as int? ?? 0, // Null gelirse 0 varsayılan değer
    );
  }
}
