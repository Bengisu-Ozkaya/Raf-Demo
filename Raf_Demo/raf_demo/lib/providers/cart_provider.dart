import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/shop.dart'; // Keep this import
import '../models/shop_package.dart';
import '../models/order_model.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

// Sepetin dükkan bazında gruplanmış halini temsil eden yardımcı sınıf
class CartShop {
  final int shopId;
  final String shopName;
  final String? shopPhone;
  final Map<int, CartItem> items; // Product ID veya Paket Negatif ID -> CartItem

  CartShop({
    required this.shopId,
    required this.shopName,
    this.shopPhone,
    required this.items,
  });

  // JSON serileştirme
  Map<String, dynamic> toJson() => {
        'shopId': shopId,
        'shopName': shopName,
        'shopPhone': shopPhone,
        'items': items.map((k, v) => MapEntry(k.toString(), v.toJson())),
      };

  factory CartShop.fromJson(Map<String, dynamic> json) => CartShop(
        shopId: json['shopId'],
        shopName: json['shopName'] ?? '',
        shopPhone: json['shopPhone'],
        items: (json['items'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), CartItem.fromJson(v))),
      );
}

class CartProvider with ChangeNotifier {
  final ApiService _apiService;
  final SocketService _socketService;
  Map<int, CartShop> _shops = {}; // Shop ID -> CartShop
  List<OrderModel> _myOrders = []; // YENİ: Sipariş geçmişini tutan liste

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<int, CartShop> get shops => _shops;
  List<OrderModel> get myOrders =>
      [..._myOrders]; // Dışarıdan değiştirilememesi için kopyasını gönder
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Sepetteki toplam ürün sayısı (ikon üzerinde göstermek için)
  int get totalItemCount {
    if (_shops.isEmpty) return 0;
    // Boş bir listede .reduce() kullanmak hata verir. .fold() kullanmak daha güvenlidir.
    return _shops.values.fold(
        0,
        (total, shop) =>
            total +
            shop.items.values
                .fold(0, (shopTotal, item) => shopTotal + item.quantity));
  }

  // Tüm sepetin toplam tutarı
  double get totalAmount {
    if (_shops.isEmpty) return 0.0;
    // Boş bir listede .reduce() kullanmak hata verir. .fold() kullanmak daha güvenlidir.
    return _shops.values.fold(
        0.0,
        (total, shop) =>
            total +
            shop.items.values
                .fold(0.0, (shopTotal, item) => shopTotal + item.totalPrice));
  }

  CartProvider(this._apiService, this._socketService) {
    loadCartFromPrefs();

    // YENİ: Sipariş durumu güncellemelerini dinle
    _socketService.onOrderStatusUpdated((updateData) {
      final int orderId = updateData['orderId'];
      final String newStatus = updateData['newStatus'];

      final index =
          _myOrders.indexWhere((order) => order.id == orderId.toString());
      if (index != -1) {
        final oldOrder = _myOrders[index];
        // OrderModel'in bir copyWith metodu olduğunu varsayıyoruz, yoksa bu şekilde yeni bir nesne oluşturulur.
        _myOrders[index] = oldOrder.copyWith(
          id: oldOrder.id,
          items: oldOrder.items,
          totalAmount: oldOrder.totalAmount,
          dateTime: oldOrder.dateTime,
          paymentMethod: oldOrder.paymentMethod,
          shopName: oldOrder.shopName,
          status: newStatus, // Durumu güncelle
        );
        notifyListeners();
      }
    });
  }

  // Ürünü sepete ekler
  void addItem(Product product, Shop shop, {int quantity = 1}) {
    if (quantity <= 0) return;

    if (!_shops.containsKey(shop.id)) {
      _shops[shop.id] = CartShop(
        shopId: shop.id,
        shopName: shop.name,
        shopPhone: shop.phone,
        items: {},
      );
    } else if (_shops[shop.id]!.shopPhone == null && shop.phone != null) {
      _shops[shop.id] = CartShop(
        shopId: shop.id,
        shopName: shop.name,
        shopPhone: shop.phone,
        items: _shops[shop.id]!.items,
      );
    }

    final cartShop = _shops[shop.id]!;

    if (cartShop.items.containsKey(product.id)) {
      final item = cartShop.items[product.id]!;
      item.quantity += quantity;
    } else {
      cartShop.items[product.id] =
          CartItem.fromProduct(product, quantity: quantity);
    }

    _saveCartAndNotify();
  }

  // Paketi sepete ekler
  void addPackage(ShopPackage package, Shop shop, {int quantity = 1}) {
    if (quantity <= 0) return;

    if (!_shops.containsKey(shop.id)) {
      _shops[shop.id] = CartShop(
        shopId: shop.id,
        shopName: shop.name,
        shopPhone: package.shopPhone ?? shop.phone,
        items: {},
      );
    } else if (_shops[shop.id]!.shopPhone == null && (package.shopPhone != null || shop.phone != null)) {
      _shops[shop.id] = CartShop(
        shopId: shop.id,
        shopName: shop.name,
        shopPhone: package.shopPhone ?? shop.phone,
        items: _shops[shop.id]!.items,
      );
    }

    final cartShop = _shops[shop.id]!;
    final packageKey = -package.id; // Paketler için negatif anahtar

    if (cartShop.items.containsKey(packageKey)) {
      final item = cartShop.items[packageKey]!;
      item.quantity += quantity;
    } else {
      cartShop.items[packageKey] = CartItem.fromPackage(package, quantity: quantity);
    }

    _saveCartAndNotify();
  }

  // Sepetteki ürünün miktarını artırır (CartListItem'den çağrılır)
  void incrementItem(int productId, int shopId, {int stockLimit = 999}) {
    if (!_shops.containsKey(shopId) ||
        !_shops[shopId]!.items.containsKey(productId)) {
      return; // Dükkan veya ürün sepette yok
    }
    final item = _shops[shopId]!.items[productId]!;
    if (item.quantity < stockLimit) {
      item.increment();
      _saveCartAndNotify();
    } else {
      // Stok dolu uyarısı, belki bir SnackBar ile kullanıcıya gösterilebilir.
    }
  }

  // Sepetteki ürünün miktarını azaltır (CartListItem'den çağrılır)
  void decrementItem(int productId, int shopId) {
    if (!_shops.containsKey(shopId) ||
        !_shops[shopId]!.items.containsKey(productId)) {
      return; // Dükkan veya ürün sepette yok
    }

    final cartItem = _shops[shopId]!.items[productId]!;
    cartItem.decrement();

    // Miktar 0'a düşerse ürünü sepetten tamamen kaldır
    if (cartItem.quantity == 0) {
      _shops[shopId]!.items.remove(productId);
      // Eğer dükkanın sepeti boşalırsa dükkanı da sepetten kaldır
      if (_shops[shopId]!.items.isEmpty) {
        _shops.remove(shopId);
      }
    }

    _saveCartAndNotify();
  }

  // Tüm sepeti temizle
  void clearCart() {
    _shops = {};
    _saveCartAndNotify();
  }

  // Siparişi ver
  Future<bool> placeOrder({
    required String userId,
    required String userName,
    required String paymentMethod,
  }) async {
    if (_shops.isEmpty) {
      _setError("Sepetiniz boş.");
      return false;
    }
    _setLoading(true);

    // Backend'in beklediği formata dönüştür: { "shopId1": { "items": [...] } }
    final Map<String, dynamic> cartsPayload = _shops.map((shopId, cartShop) {
      final itemsPayload = cartShop.items.values.map((item) {
        // Backend'e ürünün tüm detaylarını gönderiyoruz.
        return item.toJson();
      }).toList();
      return MapEntry(shopId.toString(), {'items': itemsPayload});
    });

    try {
      // GÜNCELLEME: Yeni API metodunu çağır
      await _apiService.placeOrder(
          carts: cartsPayload,
          userId: userId,
          userName: userName,
          paymentMethod: paymentMethod);

      // YENİ: Sipariş başarılıysa, sipariş listesini sunucudan yeniden çek.
      await fetchMyOrders();

      clearCart(); // Sipariş başarılıysa sepeti temizle
      _setError(null);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sepeti SharedPreferences'a kaydet
  Future<void> _saveCartAndNotify() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson =
        json.encode(_shops.map((k, v) => MapEntry(k.toString(), v.toJson())));
    await prefs.setString('cart', cartJson);
    notifyListeners();
  }

  // Sepeti SharedPreferences'dan yükle
  Future<void> loadCartFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('cart')) {
      return;
    }
    final cartJson = prefs.getString('cart')!;
    final decodedCart = json.decode(cartJson) as Map<String, dynamic>;

    _shops =
        decodedCart.map((k, v) => MapEntry(int.parse(k), CartShop.fromJson(v)));
    notifyListeners();
  }

  /// Müşterinin sipariş geçmişini sunucudan çeker.
  Future<void> fetchMyOrders() async {
    _setLoading(true); // Yükleme başladığını bildir
    try {
      _myOrders = await _apiService.fetchMyOrders();
      _setError(null);
    } catch (e) {
      _setError(e.toString());
      _myOrders = []; // Hata durumunda listeyi temizle
    } finally {
      _setLoading(false); // Yükleme bittiğini bildir
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
}
