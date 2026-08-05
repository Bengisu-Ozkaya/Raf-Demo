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
      id: json['id'],
      shopId: json['shop_id'],
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
