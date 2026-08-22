class MerchantOrderItem {
  final String name;
  final String brand;
  final int quantity;
  final double price;

  MerchantOrderItem({
    required this.name,
    required this.brand,
    required this.quantity,
    required this.price,
  });

  factory MerchantOrderItem.fromJson(Map<String, dynamic> json) {
    return MerchantOrderItem(
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MerchantOrder {
  final int id;
  final String status;
  final double totalPrice;
  final String paymentMethod;
  final DateTime orderDate;
  final String customerName;
  final List<MerchantOrderItem> items;

  MerchantOrder({
    required this.id,
    required this.status,
    required this.totalPrice,
    required this.paymentMethod,
    required this.orderDate,
    required this.customerName,
    required this.items,
  });

  factory MerchantOrder.fromJson(Map<String, dynamic> json) {
    // backend'den gelen order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP şeklindedir
    // bu yüzden DateTime.parse tarafından ayrıştırılabilen bir string olmalıdır
    final String dateString = json['order_date'] as String;
    final DateTime parsedDate = DateTime.parse(dateString);

    final List<MerchantOrderItem> parsedItems = (json['items']
                as List<dynamic>?)
            ?.map((itemJson) =>
                MerchantOrderItem.fromJson(itemJson as Map<String, dynamic>))
            .toList() ??
        [];

    return MerchantOrder(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'Bilinmiyor',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'Bilinmiyor',
      orderDate: parsedDate,
      customerName: json['customerName'] as String? ?? 'Bilinmiyor',
      items: parsedItems,
    );
  }

  MerchantOrder copyWith({
    String? status,
    double? totalPrice,
    String? paymentMethod,
    DateTime? orderDate,
    String? customerName,
    List<MerchantOrderItem>? items,
  }) {
    return MerchantOrder(
      id: id, // ID değiştirilemez
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderDate: orderDate ?? this.orderDate,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
    );
  }
}
