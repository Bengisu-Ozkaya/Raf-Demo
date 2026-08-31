import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/shop.dart';
import '../models/user.dart';
import '../models/merchant_order.dart';
import '../models/order_model.dart';
import '../models/shop_package.dart';
import '../utils/constants.dart';

class ApiService {
  final Dio _dio;
  String? _token;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: BASE_URL,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Bypass-Tunnel-Reminder': 'true',
          },
        )) {
    // Interceptor'ı SADECE BİR KEZ, servis oluşturulurken ekliyoruz.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Eğer bir token set edilmişse, her isteğin başına 'Authorization' header'ını ekle.
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
      },
    ));
  }

  /// Provider'dan gelen token'ı ayarlamak için kullanılan public metod.
  void setAuthToken(String? token) {
    _token = token;
  }

  /// Müşteri girişi yapar.
  /// Başarılı olursa 'token' ve 'user' içeren bir Map döner.
  Future<Map<String, dynamic>> loginCustomer(
      String loginIdentifier, String password) async {
    try {
      final response = await _dio.post(
        '/api/customer/login',
        data: {'loginIdentifier': loginIdentifier, 'password': password},
      );
      if (response.data['success']) {
        // AppUser.fromJson modeli, id'nin int veya string gelme durumunu
        // zaten kendisi yönettiği için ek bir dönüşüme gerek yoktur.
        return {
          'token': response.data['token'],
          'user': AppUser.fromJson(response.data['user']),
        };
      } else {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Yeni bir müşteri kaydı oluşturur.
  Future<void> registerCustomer({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String city,
  }) async {
    try {
      final response = await _dio.post(
        '/api/customer/register',
        data: {
          'username': username,
          'email': email,
          'phone': phone,
          'password': password,
          'city': city,
        },
      );
      if (!response.data['success']) {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Yeni bir dükkan sahibi (merchant) kaydı oluşturur.
  Future<void> registerMerchant({
    required String shopName,
    required String ownerName,
    required String phone,
    required String password,
    required String city,
  }) async {
    try {
      final response = await _dio.post(
        '/api/merchant/register',
        data: {
          'shop_name': shopName,
          'owner_name': ownerName,
          'phone': phone,
          'password': password,
          'city': city,
        },
      );
      if (!response.data['success']) {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Dükkan sahibi girişi yapar.
  /// Başarılı olursa 'token' ve 'shopId' içeren bir Map döner.
  Future<Map<String, dynamic>> loginMerchant(
      String identifier, String password) async {
    try {
      final response = await _dio.post(
        '/api/merchant/login',
        data: {'identifier': identifier, 'password': password},
      );
      if (response.data['success']) {
        return {
          'token': response.data['token'],
          'shopId': response.data['shopId'],
          'shopName': response.data['shopName'],
          'city': response.data['city'], // YENİ: city verisini de al
        };
      } else {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Dükkanları getirir. Opsiyonel olarak şehre göre filtreleme yapar.
  Future<List<Shop>> fetchShops({String? city}) async {
    try {
      final response = await _dio.get(
        '/api/shops',
        queryParameters:
            (city != null && city != 'Tüm Şehirler') ? {'city': city} : null,
      );
      return (response.data as List)
          .map((shopJson) => Shop.fromJson(shopJson))
          .toList();
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Belirli bir dükkanın ürünlerini getirir.
  Future<List<Product>> fetchProducts(int shopId) async {
    try {
      final response = await _dio.get(
        '/api/products',
        queryParameters: {'shopId': shopId},
      );
      if (response.data != null) {
        return (response.data as List)
            .map((productJson) => Product.fromJson(productJson))
            .toList();
      }
      return []; // Ürün yoksa boş liste dön
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Master ürünleri getirir. Opsiyonel olarak kategori ve aramaya göre filtreleme yapar.
  Future<List<Product>> fetchMasterProducts(
      {String? category, String? search}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (category != null && category != 'Tümü') {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get(
        '/api/master-products',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.data != null && response.data['data'] is List) {
        return (response.data['data'] as List)
            .map((productJson) => Product.fromJson(productJson))
            .toList();
      }
      return []; // Ürün yoksa boş liste dön
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Sepetteki ürünleri birden fazla dükkan için sipariş verir (GÜNCELLENDİ).
  Future<void> placeOrder({
    required Map<String, dynamic> carts,
    required String userId,
    required String userName,
    required String paymentMethod,
  }) async {
    try {
      final response = await _dio.post(
        '/api/orders', // Endpoint /api/orders olarak güncellendi
        data: {
          'carts': carts,
          'userId': userId,
          'userName': userName,
          'paymentMethod': paymentMethod,
        },
      );
      if (!response.data['success']) {
        throw Exception(response.data['message'] ?? 'Sipariş oluşturulamadı.');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // --- YENİ: MÜŞTERİ SİPARİŞLERİNİ ÇEKME ---
  Future<List<OrderModel>> fetchMyOrders() async {
    try {
      // Bu endpoint artık token ile korunduğu için ApiService interceptor'ı
      // otomatik olarak Authorization header'ını ekleyecektir.
      final response = await _dio.get('/api/customer/orders');
      if (response.data != null && response.data is List) {
        return (response.data as List)
            .map((orderData) => OrderModel.fromJson(orderData))
            .toList();
      }
      return []; // Sipariş yoksa boş liste dön
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // --- YENİ: SATICI SİPARİŞLERİNİ ÇEKME ---
  Future<List<MerchantOrder>> fetchMerchantOrders(int shopId) async {
    try {
      // Backend, token'dan satıcıyı tanıdığı için URL'de shopId göndermeye gerek yok.
      final response = await _dio.get(
        // Token otomatik eklenir.
        '/api/merchant/orders',
      );
      if (response.data != null && response.data is List) {
        return (response.data as List)
            .map((orderData) => MerchantOrder.fromJson(orderData))
            .toList();
      }
      return []; // Sipariş yoksa boş liste dön
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // --- YENİ: SİPARİŞ DURUMUNU GÜNCELLEME ---
  Future<void> updateOrderStatus(int orderId, String status) async {
    try {
      // Bu endpoint token ile korunduğu için interceptor header'ı ekleyecektir.
      final response = await _dio.put(
        '/api/orders/$orderId/status',
        data: {'status': status},
      );
      if (response.data == null || response.data['success'] != true) {
        throw Exception(
            response.data['message'] ?? 'Sipariş durumu güncellenemedi.');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // --- YENİ: İŞLETMECİ ÜRÜN YÖNETİMİ METODLARI ---

  /// Belirli bir dükkanın ürünlerini getirir (İşletmeci paneli için).
  Future<List<Product>> fetchProductsForMerchant(int shopId) async {
    try {
      final response = await _dio.get(
        '/api/products',
        queryParameters: {'shopId': shopId},
      );
      return (response.data as List)
          .map((productJson) => Product.fromJson(productJson))
          .toList();
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Yeni bir ürün ekler.
  Future<void> addProduct({
    required double price,
    required int stock,
    required int masterProductId, // YENİ: master_product_id eklendi
  }) async {
    // DİKKAT: Normalde token yönetimi merkezi interceptor tarafından yapılır.
    // Ancak bu kritik işlemde token'ın kesinlikle gönderildiğinden emin olmak için
    // token'ı manuel olarak okuyup header'a ekliyoruz. Bu, olası zamanlama
    // sorunlarını ortadan kaldıran bir "güvenlik" önlemidir.
    try {
      // 1. Kaydedilmiş token'ı yerel hafızadan oku veya mevcut _token'ı kullan.
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? _token;

      // 2. Token yoksa hata fırlat. Bu, giriş yapılmadığını gösterir.
      if (token == null) {
        throw Exception(
            'Doğrulama hatası: Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      }

      // 3. Dio isteğini, header'a manuel olarak eklenmiş token ile gönder.
      final response = await _dio.post(
        '/api/products',
        data: {
          'master_product_id':
              masterProductId, // YENİ: master_product_id gönderiliyor
          'price': price,
          'stock': stock,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (!response.data['success']) {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Seçilen paketteki ürünleri toplu olarak dükkana ekler.
  Future<int> addProductsBatch({
    required List<Map<String, dynamic>> products,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? _token;

      if (token == null) {
        throw Exception(
            'Doğrulama hatası: Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.post(
        '/api/products/batch',
        data: {
          'products': products,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data != null && response.data['success'] == true) {
        return response.data['count'] ?? products.length;
      } else {
        throw Exception(response.data?['message'] ?? 'Ürünler eklenemedi.');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Bir ürünün fiyatını ve/veya stoğunu günceller.
  Future<void> updateProduct(int shopProductId,
      {double? price, int? stock}) async {
    try {
      final response = await _dio.put(
        '/api/products/$shopProductId', // shopProductId kullanılıyor
        data: {'price': price, 'stock': stock},
      );
      if (!response.data['success']) {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Bir ürünü siler.
  Future<void> deleteProduct(int shopProductId) async {
    try {
      await _dio
          .delete('/api/products/$shopProductId'); // shopProductId kullanılıyor
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // --- PAKET İŞLEMLERİ (PACKAGE METHODS) ---

  /// Belirli bir dükkanın paketlerini getirir.
  Future<List<ShopPackage>> fetchPackages(int shopId) async {
    try {
      final response = await _dio.get(
        '/api/packages',
        queryParameters: {'shopId': shopId},
      );
      if (response.data != null && response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list.map((json) => ShopPackage.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Yeni bir paket oluşturur.
  Future<int> createPackage({
    required String name,
    String? description,
    String packageSize = 'Standart Paket',
    required double totalPrice,
    required int stock,
    List<Map<String, dynamic>> items = const [],
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? _token;

      if (token == null) {
        throw Exception('Doğrulama hatası: Oturum bulunamadı.');
      }

      final payload = <String, dynamic>{
        'name': name,
        'package_size': packageSize,
        'total_price': totalPrice,
        'stock': stock,
        'items': items,
      };
      if (description != null && description.isNotEmpty) {
        payload['description'] = description;
      }

      final response = await _dio.post(
        '/api/packages',
        data: payload,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.data != null && response.data['success'] == true) {
        return response.data['packageId'] ?? 0;
      } else {
        throw Exception(response.data?['message'] ?? 'Paket oluşturulamadı.');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Bir paketin adını, fiyatını veya stoğunu günceller.
  Future<void> updatePackage(
    int packageId, {
    String? name,
    double? totalPrice,
    int? stock,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? _token;

      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (totalPrice != null) data['total_price'] = totalPrice;
      if (stock != null) data['stock'] = stock;

      final response = await _dio.put(
        '/api/packages/$packageId',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['message'] ?? 'Paket güncellenemedi.');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Bir paketi siler.
  Future<void> deletePackage(int packageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? _token;

      final response = await _dio.delete(
        '/api/packages/$packageId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['message'] ?? 'Paket silinemedi.');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // Dio'dan gelen hataları yakalayıp daha anlaşılır mesajlara çeviren yardımcı fonksiyon.
  Exception _handleDioException(DioException e) {
    // Sunucudan yapısal bir hata mesajı geldiyse onu kullan.
    if (e.response?.data is Map && e.response!.data['message'] != null) {
      return Exception(e.response!.data['message']);
    }

    // Aksi halde, ağ hatasının tipine göre daha açıklayıcı bir mesaj oluştur.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception(
            'Sunucuya bağlanırken zaman aşımı oluştu. İnternet bağlantınızı kontrol edin.');
      case DioExceptionType.connectionError:
        return Exception(
            'Sunucuya bağlanılamadı. Sunucunun çalıştığından ve IP/URL adresinin doğru olduğundan emin olun.');
      case DioExceptionType.badResponse:
        return Exception(
            'Sunucudan geçersiz bir yanıt alındı (Hata Kodu: ${e.response?.statusCode}).');
      case DioExceptionType.cancel:
        return Exception('İstek iptal edildi.');
      default:
        return Exception(
            'Bilinmeyen bir ağ hatası oluştu. Lütfen tekrar deneyin.');
    }
  }
}
