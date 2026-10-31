import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';
import '../models/product.dart';
import 'dart:async';

/// WebSocket bağlantısını ve olaylarını yöneten servis sınıfı.
class SocketService {
  IO.Socket? _socket;

  // Dışarıdan dinlenebilecek bir StreamController oluşturuyoruz.
  // Bu, stok güncellemelerini UI katmanına (Provider aracılığıyla) iletecek.
  final StreamController<Map<String, dynamic>> _stockUpdateController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get stockUpdateStream =>
      _stockUpdateController.stream;

  /// Sunucuya WebSocket bağlantısı başlatır.
  void connect() {
    if (_socket != null && _socket!.connected) {
      return;
    }

    _socket = IO.io(BASE_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {});

    // 'products-updated' event'ini dinle (Tüm liste gelir: Ekleme/Silme/Güncelleme sonrası)
    _socket!.on('products-updated', (data) {
      if (data is Map<String, dynamic> && data.containsKey('products')) {
        try {
          final products = (data['products'] as List)
              .map((item) => Product.fromJson(item as Map<String, dynamic>))
              .toList();

          _stockUpdateController.add({
            'type': 'full_update',
            'shopId': data['shopId'],
            'products': products
          });
        } catch (_) {}
      }
    });

    // 'stock-updated' event'ini dinle (Tek ürün stoğu/fiyatı güncellenir)
    _socket!.on('stock-updated', (data) {
      if (data is Map<String, dynamic> &&
          data.containsKey('shopProductId') &&
          data.containsKey('newStock')) {
        try {
          _stockUpdateController.add({
            'type': 'partial_update',
            'productId': data['shopProductId'],
            'newStock': data['newStock'],
            'newPrice': data['newPrice'],
          });
        } catch (_) {}
      }
    });

    _socket!.onDisconnect((_) {});
    _socket!.onError((_) {});
  }

  void joinShopRoom(int shopId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join-shop-room', shopId);
    }
  }

  void joinCustomerRoom(String customerId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join-customer-room', customerId);
    }
  }

  void joinMerchantRoom(int shopId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join-merchant-room', shopId);
    }
  }

  /// Servis sonlandığında kaynakları temizler.
  void dispose() {
    _socket?.dispose();
    _stockUpdateController.close();
  }
}
