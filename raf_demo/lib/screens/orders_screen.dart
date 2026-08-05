import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart'; // Bu import'u koru
import '../models/order_model.dart';
import 'shops_screen.dart';

/// Kullanıcının geçmiş siparişlerini listeleyen ekran.
class OrdersScreen extends StatefulWidget {
  static const routeName = '/orders';

  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // _ordersFuture artık gerekli değil, doğrudan Consumer kullanacağız.

  @override
  void initState() {
    super.initState();
    // Ekran ilk açıldığında siparişleri çek.
    // listen: false çünkü sadece metodu çağırıyoruz, build metodunda dinleyeceğiz.
    Provider.of<CartProvider>(context, listen: false).fetchMyOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişlerim'), // Başlık
      ),
      body: Consumer<CartProvider>(
        builder: (ctx, cartProvider, _) {
          // Yükleme durumunu ve hata mesajını doğrudan provider'dan al.
          if (cartProvider.isLoading && cartProvider.myOrders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cartProvider.errorMessage != null) {
            return Center(
                child: Text(
                    'Siparişler yüklenirken bir hata oluştu: ${cartProvider.errorMessage}'));
          }

          final orders = cartProvider.myOrders;

          // Eğer hiç sipariş yoksa, kullanıcıyı bilgilendir.
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    'Henüz bir siparişiniz bulunmamaktadır',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Alışverişe Başla'),
                    onPressed: () {
                      // Kullanıcıyı ana ekrana (mağazalar) yönlendir.
                      Navigator.of(context)
                          .pushReplacementNamed(ShopsScreen.routeName);
                    },
                  )
                ],
              ),
            );
          }

          // Siparişleri en yeniden eskiye doğru listele.
          return RefreshIndicator(
            onRefresh: () => cartProvider.fetchMyOrders(), // Yenileme işlemi
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (ctx, i) => OrderItemCard(order: orders[i]),
            ),
          );
        },
      ),
    );
  }
}

/// Her bir siparişi temsil eden, açılır-kapanır kart widget'ı.
class OrderItemCard extends StatelessWidget {
  final OrderModel order;

  // Duruma göre renk belirleyen, daha kapsamlı yardımcı fonksiyon.
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'Teslim Edildi':
      case 'delivered':
        return Colors.green;
      case 'Yola Çıktı':
      case 'on the way':
        return Colors.blue.shade700;
      case 'Hazırlanıyor':
      case 'preparing':
        return Colors.orange.shade700;
      case 'İptal Edildi':
      case 'cancelled':
        return Colors.red;
      case 'pending':
      case 'Sipariş Alındı':
      case 'bekleniyor':
        return Colors.grey.shade600;
      default: // Bilinmeyen durumlar için varsayılan renk
        return Colors.grey.shade600;
    }
  }

  // Durum metnini Türkçeleştiren yardımcı fonksiyon.
  String _getTurkishStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'sipariş alındı':
      case 'bekleniyor':
        return 'Bekleniyor';
      case 'preparing':
      case 'hazırlanıyor':
        return 'Hazırlanıyor';
      case 'on the way':
      case 'yola çıktı':
        return 'Yola Çıktı';
      case 'delivered':
      case 'teslim edildi':
        return 'Teslim Edildi';
      case 'cancelled':
      case 'iptal edildi':
        return 'İptal Edildi';
      default:
        return status; // Bilinmeyen bir durum gelirse olduğu gibi göster
    }
  }

  const OrderItemCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(
          'Sipariş ID: ${order.id.length > 6 ? '...${order.id.substring(order.id.length - 6)}' : order.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(order.dateTime),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                _getTurkishStatus(order.status),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
              backgroundColor: _getStatusColor(order.status),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        trailing: Text(
          '${order.totalAmount.toStringAsFixed(2)} TL',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
        ),
        // Kart açıldığında görünecek olan ürün detayları
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ödeme Yöntemi: ${order.paymentMethod}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                const Text('Sipariş İçeriği:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                // Siparişteki her bir ürünü listele
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Ürün adı ve adedi
                          Expanded(
                              child: Text('${item.quantity}x  ${item.name}')),
                          // Ürünün o anki fiyatı
                          Text('${item.price.toStringAsFixed(2)} TL'),
                        ],
                      ),
                    )),
              ],
            ),
          )
        ],
      ),
    );
  }
}
