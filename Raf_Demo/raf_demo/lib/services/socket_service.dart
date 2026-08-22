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
  // YENİ: Yeni siparişleri dinlemek için StreamController
  final StreamController<Map<String, dynamic>> _newOrderController =
      StreamController.broadcast();
  // YENİ: Sipariş durumu güncellemelerini dinlemek için StreamController
  final StreamController<Map<String, dynamic>> _orderStatusUpdateController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get stockUpdateStream =>
      _stockUpdateController.stream;
  Stream<Map<String, dynamic>> get orderStatusUpdateStream =>
      _orderStatusUpdateController.stream;

  /// Sunucuya WebSocket bağlantısı başlatır.
  void connect() {
    // Zaten bağlıysak tekrar deneme.
    if (_socket != null && _socket!.connected) {
      return;
    }

    // Bağlantı ayarları
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

          // Stream'e 'full_update' tipinde yeni veriyi ekle
          _stockUpdateController.add({
            'type': 'full_update',
            'shopId': data['shopId'],
            'products': products
          });
        } catch (e) {
          // print('Socket event parsing error (products-updated): $e');
        }
      }
    });

    // 'stock-updated' event'ini dinle (Tek ürün stoğu/fiyatı güncellenir)
    _socket!.on('stock-updated', (data) {
      if (data is Map<String, dynamic> &&
          data.containsKey('shopProductId') &&
          data.containsKey('newStock')) {
        try {
          // Stream'e 'partial_update' tipinde yeni veriyi ekle
          _stockUpdateController.add({
            'type': 'partial_update',
            'productId':
                data['shopProductId'], // Backend'den gelen anahtarı map'le
            'newStock': data['newStock'],
            'newPrice': data['newPrice'], // Fiyat güncellemesi de gelebilir
          });
        } catch (e) {
          // print('Socket event parsing error (stock-updated): $e');
        }
      }
    });

    // YENİ: 'yeni-siparis' event'ini dinle
    _socket!.on('yeni-siparis', (data) {
      if (data is Map<String, dynamic>) {
        // Stream'e yeni sipariş verisini ekle
        _newOrderController.add(data);
      }
    });

    // YENİ: 'order-status-updated' event'ini dinle
    _socket!.on('order-status-updated', (data) {
      if (data is Map<String, dynamic>) {
        _orderStatusUpdateController.add(data);
      }
    });

    _socket!.onDisconnect((_) {});
    _socket!.onError((err) {});
  }

  void joinShopRoom(int shopId) {
    if (_socket != null && _socket!.connected) {
      // Backend'deki event adı 'join-shop-room' olarak güncellendi
      _socket!.emit('join-shop-room', shopId);
    } else {
      // Bağlantı yok, belki bir hata fırlatılabilir veya yeniden bağlanma denenebilir.
    }
  }

  // YENİ: Müşterinin kendi özel odasına katılması için metod
  void joinCustomerRoom(String customerId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join-customer-room', customerId);
    }
  }

  // YENİ: Satıcının kendi özel odasına katılması için metod
  void joinMerchantRoom(int shopId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join-merchant-room', shopId);
    }
  }

  // YENİ: Dışarıdan yeni siparişleri dinlemek için bir yol sağlar.
  // Provider bu metodu kullanarak bir callback fonksiyonu kaydeder.
  void onNewOrder(Function(Map<String, dynamic>) handler) {
    _newOrderController.stream.listen(handler);
  }

  // YENİ: Dışarıdan sipariş durumu güncellemelerini dinlemek için bir yol sağlar.
  void onOrderStatusUpdated(Function(Map<String, dynamic>) handler) {
    _orderStatusUpdateController.stream.listen(handler);
  }

  /// Servis sonlandığında kaynakları temizler.
  void dispose() {
    _socket?.dispose();
    _stockUpdateController.close();
    _newOrderController.close();
    _orderStatusUpdateController.close();
  }
}
