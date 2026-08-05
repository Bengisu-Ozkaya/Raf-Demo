import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/merchant_order.dart'; // YENİ

class ShopProvider with ChangeNotifier {
  final ApiService _apiService;
  final SocketService _socketService; // SocketService'i dışarıdan alacağız

  // State variables
  List<Shop> _shops = [];
  List<Shop> _filteredShops = [];
  List<Product> _products = [];
  List<Product> _merchantProducts = []; // YENİ: İşletmecinin kendi ürünleri
  List<Product> _masterProducts =
      []; // YENİ: Master ürünler (işletmeci ekleme ekranı için)
  List<MerchantOrder> _merchantOrders = []; // YENİ: İşletmecinin siparişleri
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCity = 'Tüm Şehirler';
  String _searchQuery = '';

  // Stream subscription
  late StreamSubscription<Map<String, dynamic>> _stockUpdateSubscription;

  // Getters
  List<Shop> get shops => _filteredShops;
  List<Product> get products => _products;
  List<Product> get merchantProducts => _merchantProducts; // YENİ
  List<Product> get masterProducts => _masterProducts; // YENİ
  List<MerchantOrder> get merchantOrders => _merchantOrders; // YENİ
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCity => _selectedCity;

  ShopProvider(this._apiService, this._socketService) {
    // --- YENİ: Satıcı için gelen yeni siparişleri dinle ---
    _socketService.onNewOrder((orderData) {
      final newOrder = MerchantOrder.fromJson(orderData);
      _merchantOrders.insert(0, newOrder); // Yeni siparişi listenin başına ekle
      notifyListeners();
    });

    // YENİ: Sipariş durumu güncellemelerini dinle (hem müşteri hem satıcı için)
    _socketService.onOrderStatusUpdated((updateData) {
      final int orderId = updateData['orderId'];
      final String newStatus = updateData['newStatus'];
      final int merchantId = updateData['merchantId'];

      // Bu provider sadece satıcının siparişlerini tuttuğu için,
      // gelen güncellemenin bu satıcıya ait olup olmadığını kontrol edebiliriz.
      final index = _merchantOrders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        // MerchantOrder modelinin bir copyWith veya benzeri bir metodu olduğunu varsayıyoruz.
        // Yoksa, nesneyi yeniden oluştururuz.
        final oldOrder = _merchantOrders[index];
        _merchantOrders[index] = oldOrder.copyWith(status: newStatus);
        notifyListeners();
      }
    });

    _stockUpdateSubscription =
        _socketService.stockUpdateStream.listen((updateData) {
      final type = updateData['type'];

      if (type == 'full_update') {
        // --- TAM GÜNCELLEME: Tüm ürün listesi geldi (Ekleme/Silme/Güncelleme) ---
        final int updatedShopId = updateData['shopId'];
        final List<Product> updatedProducts = updateData['products'];

        // Müşteri ekranındaki ürünleri güncelle (eğer o dükkandaysa)
        if (_products.isNotEmpty && _products.first.shopId == updatedShopId) {
          _products = updatedProducts;
        }
        // İşletmeci panelindeki ürünleri güncelle
        if (_merchantProducts.isNotEmpty &&
            _merchantProducts.first.shopId == updatedShopId) {
          _merchantProducts = updatedProducts;
        }
        notifyListeners();
      } else if (type == 'partial_update') {
        // --- KISMİ GÜNCELLEME (stock-updated eventi) ---
        final int productId = updateData['productId'];
        final int newStock = updateData['newStock'];
        final double? newPrice = (updateData['newPrice'] as num?)
            ?.toDouble(); // Fiyatı da al, null olabilir.

        // Müşteri ürün listesini güncelle
        final pIndex = _products.indexWhere((p) => p.id == productId);
        if (pIndex != -1) {
          _products[pIndex] = _products[pIndex].copyWith(
            stock: newStock,
            price: newPrice ??
                _products[pIndex].price, // Fiyat null değilse güncelle
          );
        }

        // İşletmeci ürün listesini güncelle
        final mIndex = _merchantProducts.indexWhere((p) => p.id == productId);
        if (mIndex != -1) {
          _merchantProducts[mIndex] = _merchantProducts[mIndex].copyWith(
            stock: newStock,
            price: newPrice ??
                _merchantProducts[mIndex].price, // Fiyat null değilse güncelle
          );
        }
        notifyListeners();
      }
    });
  }

  /// YENİ: Müşteri ekranında gösterilecek ürünleri _selectedCity'ye göre çeker.
  /// Eğer 'Tüm Şehirler' seçiliyse, tüm dükkanlardaki ürünleri toplar.
  Future<void> fetchCustomerProducts() async {
    _isLoading = true;
    _products = []; // Önceki ürünleri temizle
    _errorMessage = null;
    Future.microtask(() => notifyListeners());

    try {
      // 'Tüm Şehirler' seçiliyse şehir filtresi gönderme (null), aksi halde seçili şehri gönder.
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
    // Yükleme durumunu göstermek için arayüzü hemen güncelle.
    // Bu çağrı, build döngüsünden hemen sonraya ertelendiği için güvenlidir.
    Future.microtask(() => notifyListeners());

    try {
      // 'Tüm Şehirler' seçiliyse şehir filtresi olmadan tüm dükkanları çek.
      final cityFilter = _selectedCity == 'Tüm Şehirler' ? null : _selectedCity;
      _shops = await _apiService.fetchShops(city: cityFilter);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _shops = []; // Hata durumunda eski veriyi göstermemek için temizle
    } finally {
      _isLoading = false;
      _applyFilters();
    }
  }

  // Belirli bir dükkanın ürünlerini çek
  Future<void> fetchProductsForShop(int shopId) async {
    _isLoading = true;
    _products = []; // Önceki ürünleri temizle
    _errorMessage = null;
    // Yükleme durumunu göstermek için arayüzü güvenli bir şekilde güncelle.
    Future.microtask(() => notifyListeners());

    try {
      _products = await _apiService.fetchProducts(shopId);
      _socketService.joinShopRoom(shopId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      // Tüm state değişiklikleri bitti, arayüzü son haliyle güncelle.
      notifyListeners();
    }
  }

  // YENİ: Belirli bir kategoriye ait master ürünleri çeker (işletmeci ekleme ekranı için)
  Future<void> fetchMasterProductsByCategory(String category) async {
    _isLoading = true;
    _masterProducts = [];
    _errorMessage = null;
    Future.microtask(() => notifyListeners());

    try {
      // YENİ: "Tümü" seçildiğinde kategori filtresi gönderme (null).
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

  // --- YENİ: Satıcının geçmiş siparişlerini çek ---
  Future<void> fetchMerchantOrders(int shopId) async {
    _isLoading = true;
    _errorMessage = null;
    // Yükleme durumunu göstermek için arayüzü güvenli bir şekilde güncelle.
    Future.microtask(() => notifyListeners());

    try {
      _merchantOrders = await _apiService.fetchMerchantOrders(shopId);
    } catch (e) {
      _errorMessage = e.toString();
      _merchantOrders = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void joinMerchantRoom(int shopId) {
    _socketService.joinMerchantRoom(shopId);
  }

  // --- YENİ: İŞLETMECİ ÜRÜN YÖNETİMİ ---

  Future<void> fetchMerchantProducts(int shopId) async {
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
    required int masterProductId, // YENİ: masterProductId eklendi
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.addProduct(
          masterProductId: masterProductId, price: price, stock: stock);
      // Socket olayı arayüzü güncelleyeceği için burada sadece loading durumunu bitiriyoruz.
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

  Future<void> updateProduct(
      int shopProductId, int shopId, // shopProductId kullanılıyor
      {double? price,
      int? stock}) async {
    // Bu işlem için arayüzde anlık bir değişiklik (loading indicator) göstermiyoruz,
    // çünkü güncelleme genellikle hızlıdır ve socket tarafından yansıtılır.
    try {
      await _apiService.updateProduct(shopProductId,
          price: price, stock: stock);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // --- YENİ: SİPARİŞ DURUMUNU GÜNCELLEME ---
  Future<void> updateOrderStatus(int orderId, String newStatus) async {
    try {
      await _apiService.updateOrderStatus(orderId, newStatus);
      // Arayüz güncellemesi socket event'i ile otomatik olarak yapılacak.
      // İsteğe bağlı olarak burada anlık geri bildirim için optimistic update yapılabilir:
      /*
      final index = _merchantOrders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _merchantOrders[index] = _merchantOrders[index].copyWith(status: newStatus);
        notifyListeners();
      }
      */
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      // Hata durumunda optimistic update'i geri almak gerekebilir.
      // Şimdilik sadece hatayı bildiriyoruz.
    }
  }

  Future<void> deleteProduct(int productId, int shopId) async {
    // Silme işlemi için de anlık bir loading göstermiyoruz.
    try {
      await _apiService.deleteProduct(
          productId); // productId burada shop_product_id'yi temsil ediyor.
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Şehir seçimi
  void selectCity(String city) {
    _selectedCity = city;
    fetchShops(); // Dükkan listesini günceller (ve içinde _applyFilters çağırır)
    fetchCustomerProducts(); // Seçilen şehre göre müşteri ürün listesini günceller
  }

  // Dükkan arama
  void searchShops(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  // Filtreleme mantığı
  void _applyFilters() {
    // API'den gelen ana listeyi al. Şehir filtresi zaten backend'de uygulanmıştır.
    List<Shop> tempShops = _shops;

    // Sadece arama sorgusuna göre client-side (uygulama tarafında) filtreleme yap.
    if (_searchQuery.isNotEmpty) {
      tempShops = tempShops
          .where((shop) =>
              shop.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Görüntülenecek listeyi güncelle ve dinleyicileri bilgilendir.
    _filteredShops = tempShops;
    // "setState() or markNeedsBuild() called during build" hatasını önlemek için
    // notifyListeners() çağrısını build döngüsünün hemen sonrasına erteliyoruz.
    // Bu, bu metodun build() içinden çağrıldığı durumlarda uygulamanın çökmesini engeller.
    Future.microtask(() => notifyListeners());
  }

  @override
  void dispose() {
    _stockUpdateSubscription.cancel(); // Stream'i temizle
    super.dispose();
  }
}
