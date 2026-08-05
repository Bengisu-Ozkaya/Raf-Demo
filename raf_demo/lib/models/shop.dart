/// API'den gelen dükkan verilerini temsil eden model sınıfı.
class Shop {
  final int id;
  final String name;
  final String city;
  final String? imageUrl;

  Shop({
    required this.id,
    required this.name,
    required this.city,
    this.imageUrl,
  });

  /// JSON verisinden bir Shop nesnesi oluşturur.
  /// Backend'den gelen `shop_name` alanını `name` olarak haritalar.
  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'],
      name: json['shop_name'],
      city: json['city'],
      imageUrl: json['image_url'],
    );
  }
}
