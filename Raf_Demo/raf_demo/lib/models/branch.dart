/// Dükkan şubesi verisini temsil eden model sınıfı.
class Branch {
  final int id;
  final int shopId;
  final String city;
  final String? fullAddress;

  Branch({
    required this.id,
    required this.shopId,
    required this.city,
    this.fullAddress,
  });

  /// Gelen JSON verisinden bir Branch nesnesi oluşturur.
  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      shopId: json['shop_id'] is int ? json['shop_id'] : int.tryParse(json['shop_id']?.toString() ?? '0') ?? 0,
      city: json['city'],
      fullAddress: json['full_address'],
    );
  }

  /// Branch nesnesini JSON formatına çevirir.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'city': city,
      'full_address': fullAddress,
    };
  }
}
