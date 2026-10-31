import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/shop.dart';
import '../models/shop_package.dart';
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

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<int, CartShop> get shops => _shops;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Sepetteki toplam ürün sayısı (ikon üzerinde göstermek için)
  int get totalItemCount {
    if (_shops.isEmpty) return 0;
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
    return _shops.values.fold(
        0.0,
        (total, shop) =>
            total +
            shop.items.values
                .fold(0.0, (shopTotal, item) => shopTotal + item.totalPrice));
  }

  CartProvider(this._apiService, this._socketService) {
    loadCartFromPrefs();
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
      return;
    }
    final item = _shops[shopId]!.items[productId]!;
    if (item.quantity < stockLimit) {
      item.increment();
      _saveCartAndNotify();
    }
  }

  // Sepetteki ürünün miktarını azaltır (CartListItem'den çağrılır)
  void decrementItem(int productId, int shopId) {
    if (!_shops.containsKey(shopId) ||
        !_shops[shopId]!.items.containsKey(productId)) {
      return;
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
}
