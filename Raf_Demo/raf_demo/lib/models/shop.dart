/// API'den gelen dükkan verilerini temsil eden model sınıfı.
class Shop {
  final int id;
  final String name;
  final String city;
  final String? phone;
  final String? imageUrl;

  Shop({
    required this.id,
    required this.name,
    required this.city,
    this.phone,
    this.imageUrl,
  });

  /// JSON verisinden bir Shop nesnesi oluşturur.
  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ??
              (json['id']?.toString().hashCode.abs() ?? 0),
      name: json['shop_name'] ?? json['name'] ?? '',
      city: json['city'] ?? '',
      phone: json['phone']?.toString(),
      imageUrl: json['image_url'],
    );
  }
}
