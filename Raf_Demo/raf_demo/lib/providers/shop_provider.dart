import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/shop_package.dart';

class ShopProvider with ChangeNotifier {
  final ApiService _apiService;
  final SocketService _socketService;

  // State variables
  List<Shop> _shops = [];
  List<Shop> _filteredShops = [];
  List<Product> _products = [];
  List<Product> _merchantProducts = [];
  List<ShopPackage> _merchantPackages = [];
  List<Product> _masterProducts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCity = 'Tüm Şehirler';
  String _searchQuery = '';

  // Stream subscription
  late StreamSubscription<Map<String, dynamic>> _stockUpdateSubscription;

  // Getters
  List<Shop> get shops => _filteredShops;
  List<Product> get products => _products;
  List<Product> get merchantProducts => _merchantProducts;
  List<ShopPackage> get merchantPackages => _merchantPackages;
  List<Product> get masterProducts => _masterProducts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCity => _selectedCity;

  ShopProvider(this._apiService, this._socketService) {
    _stockUpdateSubscription =
        _socketService.stockUpdateStream.listen((updateData) {
      final type = updateData['type'];

      if (type == 'full_update') {
        final rawShopId = updateData['shopId'];
        final int updatedShopId = rawShopId is int
            ? rawShopId
            : int.tryParse(rawShopId?.toString() ?? '0') ?? 0;
        final List<Product> updatedProducts = updateData['products'];

        if (_products.isNotEmpty && _products.first.shopId == updatedShopId) {
          _products = updatedProducts;
        }
        if (_merchantProducts.isNotEmpty &&
            _merchantProducts.first.shopId == updatedShopId) {
          _merchantProducts = updatedProducts;
        }
        notifyListeners();
      } else if (type == 'partial_update') {
        final rawProdId = updateData['productId'];
        final int productId = rawProdId is int
            ? rawProdId
            : int.tryParse(rawProdId?.toString() ?? '0') ?? 0;
        final int newStock = (updateData['newStock'] as num?)?.toInt() ?? 0;
        final double? newPrice = (updateData['newPrice'] as num?)?.toDouble();

        final pIndex = _products.indexWhere((p) => p.id == productId);
        if (pIndex != -1) {
          _products[pIndex] = _products[pIndex].copyWith(
            stock: newStock,
            price: newPrice ?? _products[pIndex].price,
          );
        }

        final mIndex = _merchantProducts.indexWhere((p) => p.id == productId);
        if (mIndex != -1) {
          _merchantProducts[mIndex] = _merchantProducts[mIndex].copyWith(
            stock: newStock,
            price: newPrice ?? _merchantProducts[mIndex].price,
          );
        }
        notifyListeners();
      }
    });
  }

  /// Müşteri ekranında gösterilecek ürünleri _selectedCity'ye göre çeker.
  Future<void> fetchCustomerProducts() async {
    _isLoading = true;
    _products = [];
    _errorMessage = null;
    Future.microtask(() => notifyListeners());

    try {
      final cityFilter = _selectedCity == 'Tüm Şehirler' ? null : _selectedCity;
      final shopsToFetchFrom = await _apiService.fetchShops(city: cityFilter);

      List<Product> aggregatedProducts = [];
      for (final shop in shopsToFetchFrom) {
        final shopProducts = await _apiService.fetchProducts(shop.id);
        aggregatedProducts.addAll(shopProducts);
      }
      _products = aggregatedProducts;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _products = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Dükkanları API'den çek
  Future<void> fetchShops() async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final cityFilter = _selectedCity == 'Tüm Şehirler' ? null : _selectedCity;
      _shops = await _apiService.fetchShops(city: cityFilter);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _shops = [];
    } finally {
      _isLoading = false;
      _applyFilters();
    }
  }

  // Belirli bir dükkanın ürünlerini çek
  Future<void> fetchProductsForShop(int shopId) async {
    _isLoading = true;
    _products = [];
    _errorMessage = null;
    Future.microtask(() => notifyListeners());

    try {
      _products = await _apiService.fetchProducts(shopId);
      _socketService.joinShopRoom(shopId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Belirli bir kategoriye ait master ürünleri çeker (işletmeci ekleme ekranı için)
  Future<void> fetchMasterProductsByCategory(String category) async {
    _isLoading = true;
    _masterProducts = [];
    _errorMessage = null;
    Future.microtask(() => notifyListeners());

    try {
      final categoryFilter = category == 'Tümü' ? null : category;
      _masterProducts =
          await _apiService.fetchMasterProducts(category: categoryFilter);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void joinMerchantRoom(int shopId) {
    _socketService.joinMerchantRoom(shopId);
  }

  // --- İŞLETMECİ ÜRÜN YÖNETİMİ ---

  Future<void> fetchMerchantProducts(dynamic shopId) async {
    _isLoading = true;
    _merchantProducts = [];
    _errorMessage = null;
    Future.microtask(() => notifyListeners());

    try {
      _merchantProducts = await _apiService.fetchProductsForMerchant(shopId);
    } catch (e) {
      _errorMessage = e.toString();
      _merchantProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct({
    required double price,
    required int stock,
    required int masterProductId,
    int? shopId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.addProduct(
          masterProductId: masterProductId, price: price, stock: stock);
      if (shopId != null) {
        _merchantProducts = await _apiService.fetchProductsForMerchant(shopId);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Seçilen paketteki tüm ürünleri topluca ekler ve dükkan listesini tazeler.
  Future<bool> addProductsBatch({
    required List<Map<String, dynamic>> products,
    required int shopId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.addProductsBatch(products: products);
      _merchantProducts = await _apiService.fetchProductsForMerchant(shopId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- PAKET İŞLEMLERİ (PACKAGE STATE & METHODS) ---

  /// Belirli bir dükkanın paketlerini getirir.
  Future<List<ShopPackage>> fetchPackages(dynamic shopId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _merchantPackages = await _apiService.fetchPackages(shopId);
      _isLoading = false;
      notifyListeners();
      return _merchantPackages;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// İşletmecinin paketlerini getirir.
  Future<void> fetchMerchantPackages(dynamic shopId) async => fetchPackages(shopId);

  /// Master ürün kataloğunu getirir.
  Future<List<Product>> fetchMasterProducts(
      {String? category, String? search}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _masterProducts = await _apiService.fetchMasterProducts(
          category: category, search: search);
      _isLoading = false;
      notifyListeners();
      return _masterProducts;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Yeni bir paket oluşturur ve dükkan listesini tazeler.
  Future<bool> createPackage({
    required dynamic shopId,
    required String name,
    String? description,
    String packageSize = 'Standart Paket',
    required double totalPrice,
    required int stock,
    List<Map<String, dynamic>> items = const [],
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      List<Map<String, dynamic>> finalItems = List.from(items);
      if (finalItems.isEmpty) {
        int fallbackMasterId = 1;
        try {
          if (_masterProducts.isEmpty) {
            final masters = await _apiService.fetchMasterProducts();
            if (masters.isNotEmpty) {
              _masterProducts = masters;
              fallbackMasterId = masters.first.id;
            }
          } else {
            fallbackMasterId = _masterProducts.first.id;
          }
        } catch (_) {
          fallbackMasterId = 1;
        }

        finalItems = [
          {
            'master_product_id': fallbackMasterId,
            'price': totalPrice,
            'quantity': 1,
          }
        ];
      }

      await _apiService.createPackage(
        name: name,
        description: description,
        packageSize: packageSize,
        totalPrice: totalPrice,
        stock: stock,
        items: finalItems,
      );
      await fetchMerchantPackages(shopId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Bir paketin adını, fiyatını veya stoğunu günceller.
  Future<bool> updatePackage(
    int packageId,
    int shopId, {
    String? name,
    double? totalPrice,
    int? stock,
  }) async {
    try {
      await _apiService.updatePackage(
        packageId,
        name: name,
        totalPrice: totalPrice,
        stock: stock,
      );
      await fetchMerchantPackages(shopId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Bir paketi siler.
  Future<bool> deletePackage(int packageId, int shopId) async {
    try {
      await _apiService.deletePackage(packageId);
      _merchantPackages.removeWhere((p) => p.id == packageId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProduct(
      int shopProductId, int shopId,
      {double? price,
      int? stock}) async {
    try {
      await _apiService.updateProduct(shopProductId,
          price: price, stock: stock);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteProduct(int productId, int shopId) async {
    try {
      await _apiService.deleteProduct(productId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Şehir seçimi
  void selectCity(String city) {
    _selectedCity = city;
    fetchShops();
    fetchCustomerProducts();
  }

  // Dükkan arama
  void searchShops(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  // Filtreleme mantığı
  void _applyFilters() {
    List<Shop> tempShops = _shops;

    if (_searchQuery.isNotEmpty) {
      tempShops = tempShops
          .where((shop) =>
              shop.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    _filteredShops = tempShops;
    Future.microtask(() => notifyListeners());
  }

  @override
  void dispose() {
    _stockUpdateSubscription.cancel();
    super.dispose();
  }
}
