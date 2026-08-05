import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

// Kullanıcının tipini belirtmek için enum (Müşteri mi, Satıcı mı?)
enum UserType { customer, merchant }

class AuthProvider with ChangeNotifier {
  // ApiService artık dışarıdan, constructor aracılığıyla alınıyor.
  // Bu, tüm provider'ların aynı ApiService örneğini paylaşmasını sağlar.
  final ApiService _apiService;
  final SocketService _socketService;

  // Auth durumu ve kullanıcı verileri
  String? _token;
  AppUser? _user;
  int? _shopId;
  String? _shopName;
  UserType? _userType;
  bool _isLoading = false;
  String? _errorMessage;
  bool _didTryAutoLogin = false;

  // ApiService'i parametre olarak alan constructor.
  AuthProvider(this._apiService, this._socketService);

  // Dışarıdan erişim için getter'lar
  String? get token => _token;
  AppUser? get user => _user;
  int? get shopId => _shopId;
  bool get isAuthenticated => _token != null;
  UserType? get userType => _userType;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Oturum açma (hem müşteri hem satıcı için)
  Future<bool> login(String identifier, String password, UserType type) async {
    _setLoading(true);
    try {
      if (type == UserType.customer) {
        final response = await _apiService.loginCustomer(identifier, password);
        _token = response['token'];
        _user = response['user'];
        _userType = UserType.customer;
        _shopId = null;
        _shopName = null;
        // YENİ: Müşteriyi kendi odasına dahil et
        _socketService.joinCustomerRoom(_user!.id);
      } else {
        // Dükkan sahibi market adı veya telefon numarası ile giriş yapar.
        final response = await _apiService.loginMerchant(identifier, password);
        _token = response['token'];
        _shopId = response['shopId'];
        _shopName = response['shopName'];
        _userType = UserType.merchant;
        // YENİ: Satıcıyı kendi odasına dahil et
        _socketService.joinMerchantRoom(_shopId!);
        // Satıcı için geçici bir AppUser oluşturalım
        // YENİ: Backend'den gelen city bilgisi ile kullanıcı oluşturuluyor.
        _user = AppUser(
            id: _shopId.toString(),
            username: _shopName ?? 'Satıcı',
            name: _shopName ?? 'Satıcı',
            email: '',
            city: response['city'] ?? '');
      }

      // Token ekleme işlemi artık main.dart'taki ChangeNotifierProxyProvider
      // tarafından merkezi olarak yönetiliyor. Bu satıra gerek kalmadı.
      _saveAuthData(); // Oturum verilerini kaydet
      _setError(null);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Yeni kullanıcı kaydı
  Future<bool> register({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String city,
  }) async {
    _setLoading(true);
    try {
      await _apiService.registerCustomer(
        username: username,
        email: email,
        phone: phone,
        password: password,
        city: city,
      );
      _setError(null);
      return true; // Kayıt başarılı, şimdi kullanıcı giriş yapabilir.
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Yeni dükkan sahibi kaydı
  Future<bool> registerMerchant({
    required String shopName,
    required String ownerName,
    required String phone,
    required String password,
    required String city,
  }) async {
    _setLoading(true);
    try {
      await _apiService.registerMerchant(
        shopName: shopName,
        ownerName: ownerName,
        phone: phone,
        password: password,
        city: city,
      );
      _setError(null);
      return true; // Kayıt başarılı
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Otomatik giriş denemesi
  Future<void> tryAutoLogin() async {
    // Bu fonksiyonun birden çok kez çağrılmasını engelle (FutureBuilder kaynaklı)
    if (_didTryAutoLogin) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('authData')) {
      _didTryAutoLogin = true;
      return;
    }

    final extractedData =
        json.decode(prefs.getString('authData')!) as Map<String, dynamic>;

    // DÜZELTME: Kullanıcı verisi artık her zaman 'user' anahtarından okunuyor.
    _token = extractedData['token'];
    _userType = UserType.values[extractedData['userType']];
    _user = AppUser.fromJson(extractedData['user']);

    if (_userType == UserType.customer && _user != null) {
      // YENİ: Müşteriyi kendi odasına dahil et
      _socketService.joinCustomerRoom(_user!.id);
    } else if (_userType == UserType.merchant) {
      _shopId = extractedData['shopId'];
      _shopName = extractedData['shopName'];
      if (_shopId != null) {
        _socketService.joinMerchantRoom(_shopId!);
      }
    }
    // Token ekleme işlemi artık main.dart'taki ChangeNotifierProxyProvider
    // tarafından merkezi olarak yönetiliyor. Bu satıra gerek kalmadı.

    notifyListeners();
    _didTryAutoLogin = true;
  }

  // Oturumu kapatma
  Future<void> logout() async {
    _token = null;
    _user = null;
    _shopId = null;
    _userType = null;

    final prefs = await SharedPreferences.getInstance();
    // Token'ın ApiService'ten kaldırılması main.dart'taki ProxyProvider'da
    // bu notifyListeners() çağrısı sayesinde tetiklenir. ProxyProvider,
    // isAuthenticated'in false olduğunu görüp token'ı temizleyecektir.
    await prefs.remove('authData'); // Kayıtlı veriyi sil
    // YENİ: Ayrı olarak kaydedilen token'ı da temizle.
    await prefs.remove('authToken');

    notifyListeners();
  }

  // Oturum verilerini telefona kaydetme
  Future<void> _saveAuthData() async {
    final prefs = await SharedPreferences.getInstance();

    // YENİ: Token'ı hem ayrı bir anahtarla hem de authData içinde saklıyoruz.
    // Bu, bazı özel API çağrılarında token'a doğrudan erişim için bir yedek mekanizma sağlar.
    await prefs.setString('authToken', _token!);
    final authData = {
      'token': _token,
      'userType': _userType!.index,
      'user': _user
          ?.toJson(), // DÜZELTME: Hem müşteri hem satıcı için user objesi kaydediliyor.
      'shopId': _shopId,
      'shopName': _shopName,
    };
    await prefs.setString('authData', json.encode(authData));
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
