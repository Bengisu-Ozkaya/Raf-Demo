import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/cart_provider.dart';
import '../utils/theme.dart';

class CartScreen extends StatelessWidget {
  static const routeName = '/cart';

  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final cartShops = cart.shops.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sepetim'),
      ),
      body: cartShops.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.sand, width: 1.5),
                      ),
                      child: const Icon(Icons.shopping_cart_outlined,
                          size: 64, color: AppColors.taupe),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sepetiniz Boş',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepEspresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Marketlerden hazır paketler ekleyerek sepetinizi doldurabilirsiniz.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.mochaText, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: cartShops.length,
              itemBuilder: (ctx, i) {
                final shop = cartShops[i];
                final shopItems = shop.items.values.toList();
                final int shopTotalItems = shop.items.values
                    .fold(0, (sum, item) => sum + item.quantity);
                final double shopTotalAmount = shop.items.values
                    .fold(0.0, (sum, item) => sum + item.totalPrice);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 2,
                  shadowColor: AppColors.taupe.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Dükkan Başlığı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(18)),
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storefront_rounded,
                                    color: AppColors.taupe, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  shop.shopName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepEspresso,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.sand,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$shopTotalItems Paket • ${shopTotalAmount.toStringAsFixed(2)} ₺',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepEspresso,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // O dükkana ait ürünler / paketler
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: shopItems.length,
                        separatorBuilder: (ctx, idx) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (ctx, j) {
                          final item = shopItems[j];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.sand, width: 1),
                              ),
                              child: const Icon(Icons.inventory_2_outlined,
                                  color: AppColors.deepEspresso, size: 22),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                color: AppColors.deepEspresso,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.description != null &&
                                    item.description!.isNotEmpty)
                                  Text(
                                    item.description!,
                                    style: const TextStyle(
                                        color: AppColors.mochaText,
                                        fontSize: 11.5),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.price.toStringAsFixed(2)} ₺',
                                  style: const TextStyle(
                                    color: AppColors.deepEspresso,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove,
                                        size: 16,
                                        color: AppColors.deepEspresso),
                                    onPressed: () => cart.decrementItem(
                                        item.id, shop.shopId),
                                  ),
                                  Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepEspresso,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add,
                                        size: 16,
                                        color: AppColors.deepEspresso),
                                    onPressed: () {
                                      cart.incrementItem(item.id, shop.shopId);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Dükkan Alt Butonları: WhatsApp ile Sipariş Ver
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _orderCartViaWhatsApp(context, shop),
                                icon: const Icon(Icons.chat_bubble_outline,
                                    size: 18),
                                label: Text(
                                  'WhatsApp ile Sipariş Ver (${shopTotalAmount.toStringAsFixed(2)} ₺)',
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _orderCartViaWhatsApp(BuildContext context, CartShop cartShop) async {
    final packages = cartShop.items.values.where((i) => i.isPackage).toList();
    final singleItems =
        cartShop.items.values.where((i) => !i.isPackage).toList();
    final double totalAmount =
        cartShop.items.values.fold(0.0, (sum, i) => sum + i.totalPrice);

    final buffer = StringBuffer();
    buffer.writeln(
        'Merhaba ${cartShop.shopName}! Raf uygulamasından sepetimdeki ürünler için sipariş vermek istiyorum.');
    buffer.writeln('');
    buffer.writeln('*SIPARIS OZETI:*');

    if (packages.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('*Paketler:*');
      for (final pkg in packages) {
        buffer.writeln(
            '- *${pkg.name}* (x${pkg.quantity}) - ${pkg.totalPrice.toStringAsFixed(2)} TL');
        if (pkg.description != null && pkg.description!.isNotEmpty) {
          buffer.writeln('  Icerik: ${pkg.description}');
        }
      }
    }

    if (singleItems.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('*Tekli Urunler:*');
      for (final item in singleItems) {
        final wv = item.weightVolume != null && item.weightVolume!.isNotEmpty
            ? ' (${item.weightVolume})'
            : '';
        buffer.writeln(
            '- *${item.name}*$wv (x${item.quantity}) - ${item.totalPrice.toStringAsFixed(2)} TL');
      }
    }

    buffer.writeln('');
    buffer.writeln('*Toplam Tutar:* ${totalAmount.toStringAsFixed(2)} TL');

    String rawPhone = cartShop.shopPhone ?? '';
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '90${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('90') && cleanPhone.isNotEmpty) {
      cleanPhone = '90$cleanPhone';
    }

    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İşletmeye ait bir telefon numarası bulunamadı.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final whatsAppUri = Uri.https('wa.me', '/$cleanPhone', {
      'text': buffer.toString().trim(),
    });

    try {
      if (await canLaunchUrl(whatsAppUri)) {
        await launchUrl(whatsAppUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(whatsAppUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('WhatsApp açılamadı: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
