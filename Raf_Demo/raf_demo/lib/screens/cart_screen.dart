import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/cart_provider.dart';

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
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Sepetiniz Boş',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Marketlerden hazır paketler veya tekli ürünler ekleyerek sepetinizi doldurabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: cartShops.length,
              itemBuilder: (ctx, i) {
                final shop = cartShops[i];
                final shopItems = shop.items.values.toList();
                final shopTotal = shop.items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      // Dükkan Başlığı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storefront, color: Theme.of(context).primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  shop.shopName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${shopTotal.toStringAsFixed(2)} TL',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
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
                        separatorBuilder: (ctx, idx) => const Divider(height: 1),
                        itemBuilder: (ctx, j) {
                          final item = shopItems[j];
                          return ListTile(
                            leading: item.isPackage
                                ? Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.inventory_2, color: Colors.orange.shade800, size: 22),
                                  )
                                : Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                        ? Image.network(
                                            item.imageUrl!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                                          )
                                        : const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                                  ),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: item.isPackage
                                ? Text(
                                    '📦 ${item.packageSize ?? 'Paket'} (${item.packageItemCount ?? ''} Ürün) • ${item.price.toStringAsFixed(2)} TL',
                                    style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                                  )
                                : Text(
                                    '${item.weightVolume != null ? '${item.weightVolume} • ' : ''}${item.price.toStringAsFixed(2)} TL',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                  ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () =>
                                      cart.decrementItem(item.id, shop.shopId),
                                ),
                                Text(
                                  item.quantity.toString(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () {
                                    cart.incrementItem(item.id, shop.shopId);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Dükkan Alt Butonları: WhatsApp ile Sipariş Ver
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _orderCartViaWhatsApp(context, shop),
                                icon: const Icon(Icons.chat, size: 18),
                                label: Text(
                                  '${shop.shopName} ile WhatsApp\'tan Sipariş Ver',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final singleItems = cartShop.items.values.where((i) => !i.isPackage).toList();

    final double total = cartShop.items.values.fold(0.0, (sum, i) => sum + i.totalPrice);

    final buffer = StringBuffer();
    buffer.writeln('Merhaba ${cartShop.shopName}! Raf uygulamasından sepetimdeki ürünler için sipariş vermek / iletişime geçmek istiyorum.');
    buffer.writeln('');
    buffer.writeln('🛒 *SEPET İÇERİĞİ:*');

    if (packages.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📦 *Paketler:*');
      for (final pkg in packages) {
        buffer.writeln('• ${pkg.name} (${pkg.packageSize ?? 'Paket'}) x${pkg.quantity} = ${pkg.totalPrice.toStringAsFixed(2)} TL');
      }
    }

    if (singleItems.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('🛍️ *Tekli Ürünler:*');
      for (final item in singleItems) {
        final wv = item.weightVolume != null ? ' (${item.weightVolume})' : '';
        buffer.writeln('• ${item.name}$wv x${item.quantity} = ${item.totalPrice.toStringAsFixed(2)} TL');
      }
    }

    buffer.writeln('');
    buffer.writeln('💰 *Toplam Tutar:* ${total.toStringAsFixed(2)} TL');

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

    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(buffer.toString().trim())}',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp açılamadı: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
