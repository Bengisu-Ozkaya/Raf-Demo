import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../models/order_model.dart';
import '../utils/theme.dart';
import 'shops_screen.dart';

/// Kullanıcının geçmiş siparişlerini listeleyen ekran.
class OrdersScreen extends StatefulWidget {
  static const routeName = '/orders';

  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<CartProvider>(context, listen: false).fetchMyOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişlerim'),
      ),
      body: Consumer<CartProvider>(
        builder: (ctx, cartProvider, _) {
          if (cartProvider.isLoading && cartProvider.myOrders.isEmpty) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.taupe));
          }
          if (cartProvider.errorMessage != null) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                  'Siparişler yüklenirken bir hata oluştu: ${cartProvider.errorMessage}',
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center),
            ));
          }

          final orders = cartProvider.myOrders;

          // Eğer hiç sipariş yoksa, kullanıcıyı bilgilendir.
          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppColors.cream,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined,
                          size: 64, color: AppColors.taupe),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Henüz Bir Siparişiniz Yok',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepEspresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Verdiğiniz siparişlerin durumunu ve geçmişini bu sayfadan takip edebilirsiniz.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: AppColors.mochaText),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.storefront),
                      label: const Text('Alışverişe Başla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.taupe,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .pushReplacementNamed(ShopsScreen.routeName);
                      },
                    )
                  ],
                ),
              ),
            );
          }

          // Siparişleri en yeniden eskiye doğru listele.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: RefreshIndicator(
                color: AppColors.taupe,
                onRefresh: () => cartProvider.fetchMyOrders(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: orders.length,
                  itemBuilder: (ctx, i) => OrderItemCard(order: orders[i]),
                ),
              ),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'teslim edildi':
      case 'delivered':
        return AppColors.success;
      case 'yola çıktı':
      case 'on the way':
        return AppColors.taupe;
      case 'hazırlanıyor':
      case 'preparing':
        return AppColors.sand;
      case 'iptal edildi':
      case 'cancelled':
        return AppColors.error;
      case 'pending':
      case 'sipariş alındı':
      case 'bekleniyor':
        return AppColors.dustyRose;
      default:
        return AppColors.mochaText;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'hazırlanıyor':
      case 'preparing':
      case 'pending':
      case 'sipariş alındı':
      case 'bekleniyor':
        return AppColors.deepEspresso;
      default:
        return Colors.white;
    }
  }

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
        return status;
    }
  }

  const OrderItemCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final statusTextColor = _getStatusTextColor(order.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          'Sipariş ID: ${order.id.length > 6 ? '...${order.id.substring(order.id.length - 6)}' : order.id}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.deepEspresso,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(order.dateTime),
              style: const TextStyle(color: AppColors.mochaText, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getTurkishStatus(order.status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusTextColor,
                ),
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${order.items.fold(0, (sum, i) => sum + i.quantity)} Ürün',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.deepEspresso),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment, size: 16, color: AppColors.taupe),
                    const SizedBox(width: 6),
                    Text('Ödeme Yöntemi: ${order.paymentMethod}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.deepEspresso,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Sipariş İçeriği:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepEspresso,
                        fontSize: 13)),
                const Divider(height: 16),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text('• ${item.quantity}x  ${item.name}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.deepEspresso,
                                      fontSize: 13))),
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
