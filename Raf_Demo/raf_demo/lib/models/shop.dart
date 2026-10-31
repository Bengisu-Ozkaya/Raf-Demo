/// API'den gelen dükkan verilerini temsil eden model sınıfı.
class Shop {
  final int id;
  final String rawId;
  final String name;
  final String city;
  final String? phone;
  final String? imageUrl;

  Shop({
    required this.id,
    this.rawId = '',
    required this.name,
    required this.city,
    this.phone,
    this.imageUrl,
  });

  /// JSON verisinden bir Shop nesnesi oluşturur.
  factory Shop.fromJson(Map<String, dynamic> json) {
    final raw = json['id']?.toString() ?? '';
    return Shop(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ??
              (raw.hashCode.abs()),
      rawId: raw,
      name: json['shop_name'] ?? json['name'] ?? '',
      city: json['city'] ?? '',
      phone: json['phone']?.toString(),
      imageUrl: json['image_url'],
    );
  }
}
