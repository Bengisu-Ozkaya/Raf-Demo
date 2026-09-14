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
        _apiService.setAuthToken(_token);
        // YENİ: Müşteriyi kendi odasına dahil et
        if (_user != null) {
          _socketService.joinCustomerRoom(_user!.id);
        }
      } else {
        // Dükkan sahibi market adı veya telefon numarası ile giriş yapar.
        final response = await _apiService.loginMerchant(identifier, password);
        _token = response['token'];
        _shopId = response['shopId'];
        _shopName = response['shopName'];
        _userType = UserType.merchant;
        _apiService.setAuthToken(_token);
        // YENİ: Satıcıyı kendi odasına dahil et
        if (_shopId != null) {
          _socketService.joinMerchantRoom(_shopId!);
        }
        // Satıcı için geçici bir AppUser oluşturalım
        // YENİ: Backend'den gelen city bilgisi ile kullanıcı oluşturuluyor.
        _user = AppUser(
            id: _shopId.toString(),
            username: _shopName ?? 'Satıcı',
            name: _shopName ?? 'Satıcı',
            email: '',
            city: response['city'] ?? '');
      }

      await _saveAuthData(); // Oturum verilerini kalıcı olarak kaydet
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

  // Profil bilgilerini güncelleme (hem müşteri hem satıcı için)
  Future<bool> updateProfile({
    required String name,
    required String username,
    required String email,
    required String phone,
    required String city,
  }) async {
    _setLoading(true);
    try {
      if (_userType == UserType.customer) {
        await _apiService.updateCustomerProfile(
          name: name,
          username: username,
          email: email,
          phone: phone,
          city: city,
        );
        _user = (_user != null)
            ? _user!.copyWith(
                name: name,
                username: username,
                email: email,
                phone: phone,
                city: city,
              )
            : AppUser(
                id: _user?.id ?? '0',
                username: username,
                name: name,
                email: email,
                city: city,
                phone: phone,
              );
      } else {
        // Satıcı / Dükkan Sahibi
        await _apiService.updateMerchantProfile(
          shopName: username,
          ownerName: name,
          phone: phone,
          city: city,
          email: email,
        );
        _shopName = username;
        _user = (_user != null)
            ? _user!.copyWith(
                name: name,
                username: username,
                email: email,
                phone: phone,
                city: city,
              )
            : AppUser(
                id: _shopId?.toString() ?? '0',
                username: username,
                name: name,
                email: email,
                city: city,
                phone: phone,
              );
      }

      await _saveAuthData(); // Güncellenen bilgileri SharedPreferences'a kaydet
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Otomatik giriş denemesi (Kullanıcı çıkış yapana kadar oturumunu korur)
  Future<void> tryAutoLogin() async {
    if (_didTryAutoLogin) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('authData')) {
        _didTryAutoLogin = true;
        return;
      }

      final rawData = prefs.getString('authData');
      if (rawData == null) {
        _didTryAutoLogin = true;
        return;
      }

      final extractedData = json.decode(rawData) as Map<String, dynamic>;
      final token = extractedData['token'] as String?;
      if (token == null || token.isEmpty) {
        _didTryAutoLogin = true;
        return;
      }

      _token = token;
      _apiService.setAuthToken(_token);

      if (extractedData['userType'] != null) {
        final typeIndex = extractedData['userType'] is int
            ? extractedData['userType'] as int
            : int.tryParse(extractedData['userType'].toString()) ?? 0;
        if (typeIndex >= 0 && typeIndex < UserType.values.length) {
          _userType = UserType.values[typeIndex];
        }
      }

      if (extractedData['user'] != null &&
          extractedData['user'] is Map<String, dynamic>) {
        _user = AppUser.fromJson(extractedData['user'] as Map<String, dynamic>);
      }

      if (_userType == UserType.customer && _user != null) {
        _shopId = null;
        _shopName = null;
        _socketService.joinCustomerRoom(_user!.id);
      } else if (_userType == UserType.merchant) {
        if (extractedData['shopId'] != null) {
          _shopId = extractedData['shopId'] is int
              ? extractedData['shopId'] as int
              : int.tryParse(extractedData['shopId'].toString());
        }
        _shopName = extractedData['shopName'] as String?;
        if (_shopId != null) {
          _socketService.joinMerchantRoom(_shopId!);
        }
      }

      _didTryAutoLogin = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Auto login error: $e');
      _didTryAutoLogin = true;
    }
  }

  // Oturumu kapatma
  Future<void> logout() async {
    _token = null;
    _user = null;
    _shopId = null;
    _shopName = null;
    _userType = null;
    _apiService.setAuthToken(null);
    _didTryAutoLogin = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authData'); // Kayıtlı veriyi sil
      await prefs.remove('authToken');
    } catch (e) {
      debugPrint('Logout prefs error: $e');
    }

    notifyListeners();
  }

  // Oturum verilerini telefona kaydetme
  Future<void> _saveAuthData() async {
    if (_token == null || _userType == null) return;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('authToken', _token!);
    final authData = {
      'token': _token,
      'userType': _userType!.index,
      'user': _user?.toJson(),
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
