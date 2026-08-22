import 'package:raf_demo/models/cart_item.dart'; // Import yolu düzeltildi

/// Kullanıcının geçmiş bir siparişini temsil eden model.
class OrderModel {
  final String id;
  final DateTime dateTime;
  final double totalAmount;
  final String paymentMethod;
  final List<CartItem> items;
  final String status; // YENİ: Sipariş durumu eklendi
  final String shopName; // YENİ: shopName eklendi

  OrderModel({
    required this.id,
    required this.dateTime,
    required this.totalAmount,
    required this.paymentMethod,
    required this.items,
    required this.status, // YENİ: Constructor'a eklendi
    required this.shopName, // YENİ: Constructor'a eklendi
  });

  /// SharedPreferences'a kaydetmek için nesneyi JSON'a çevirir.
  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'items': items.map((item) => item.toJson()).toList(),
        'status': status, // YENİ: JSON'a eklendi
        'shopName': shopName, // YENİ: JSON'a eklendi
      };

  /// SharedPreferences'dan okunan JSON'u nesneye çevirir.
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // 'items' listesinin doğru bir şekilde parse edildiğinden emin olalım.
    var itemsFromJson = json['items'] as List;
    List<CartItem> parsedItems =
        itemsFromJson.map((itemJson) => CartItem.fromJson(itemJson)).toList();

    return OrderModel(
      id: json['id'].toString(), // ID'nin string olduğundan emin ol
      // Backend'den 'order_date' olarak, yerelden 'dateTime' olarak gelebilir.
      dateTime: DateTime.parse(json['order_date'] ?? json['dateTime']),
      // Backend'den 'total_price' olarak, yerelden 'totalAmount' olarak gelebilir.
      totalAmount:
          (json['total_price'] ?? json['totalAmount'] as num).toDouble(),
      paymentMethod:
          json['payment_method'], // Backend'den 'payment_method' olarak geliyor
      items: parsedItems,
      status: json['status'] as String? ?? 'Bilinmiyor', // YENİ: Durum eklendi
      shopName:
          json['shopName'] as String? ?? 'Bilinmiyor', // YENİ: shopName eklendi
    );
  }

  // YENİ: copyWith metodu eklendi
  OrderModel copyWith({
    String? id,
    DateTime? dateTime,
    double? totalAmount,
    String? paymentMethod,
    List<CartItem>? items,
    String? status,
    String? shopName,
  }) {
    return OrderModel(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      status: status ?? this.status,
      shopName: shopName ?? this.shopName,
    );
  }
}
