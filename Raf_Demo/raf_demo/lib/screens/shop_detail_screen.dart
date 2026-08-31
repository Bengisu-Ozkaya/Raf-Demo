import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';
import '../providers/shop_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/custom_badge.dart';
import 'cart_screen.dart';
import 'package:raf_demo/screens/package_detail_screen.dart';

class ShopDetailScreen extends StatefulWidget {
  static const routeName = '/shop-detail';

  const ShopDetailScreen({super.key});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late Future<void> _dataFuture;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final shop = ModalRoute.of(context)!.settings.arguments as Shop;
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      _dataFuture = shopProvider.fetchPackages(shop.id);
      _isInit = true;
    }
  }

  void _openWhatsAppForSingleItem(Shop shop) async {
    String rawPhone = shop.phone ?? '';
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

    final message =
        'Merhaba ${shop.name}! Raf uygulamasından sipariş vermek / bilgi almak istiyorum.';
    final uri = Uri.https('wa.me', '/$cleanPhone', {'text': message});

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('WhatsApp açılamadı: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ModalRoute.of(context)!.settings.arguments as Shop;

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          // Sepet ikonu ve Badge
          Consumer<CartProvider>(
            builder: (_, cart, ch) => CustomBadge(
              value: cart.totalItemCount.toString(),
              child: ch!,
            ),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                Navigator.of(context).pushNamed(CartScreen.routeName);
              },
            ),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _dataFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }

          return Consumer<ShopProvider>(
            builder: (ctx, shopProvider, _) {
              final packages = shopProvider.merchantPackages;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // 1. WhatsApp Tekli Ürün Sipariş Kartı
                      _buildWhatsAppSingleOrderCard(shop),

                      const SizedBox(height: 16),

                      // 2. Hazır Paketler Başlığı
                      Row(
                        children: [
                          Icon(Icons.inventory_2,
                              color: Theme.of(context).primaryColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Hazır Paketler (${packages.length})',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 3. Paketler Listesi
                      if (packages.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 40.0, horizontal: 20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 64, color: Colors.orange.shade300),
                                const SizedBox(height: 16),
                                const Text(
                                  'Bu markette henüz hazır paket bulunmuyor.',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tekli ürün veya özel siparişleriniz için yukarıdaki WhatsApp butonunu kullanabilirsiniz.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Consumer<CartProvider>(
                          builder: (ctx, cart, _) {
                            return Column(
                              children: packages.map((pkg) {
                                final packageKey = -pkg.id;
                                final quantityInCart = cart.shops[shop.id]
                                        ?.items[packageKey]?.quantity ??
                                    0;

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () =>
                                        Navigator.of(context).pushNamed(
                                      PackageDetailScreen.routeName,
                                      arguments: pkg,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(Icons.inventory_2,
                                                    color:
                                                        Colors.orange.shade900,
                                                    size: 24),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      pkg.name,
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (pkg.stock > 0) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Stokta ${pkg.stock} adet var',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey.shade600),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color:
                                                          Colors.teal.shade300),
                                                ),
                                                child: Text(
                                                  '${pkg.totalPrice.toStringAsFixed(2)} ₺',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // Paket İçeriği Özeti
                                          if (pkg.description != null &&
                                              pkg.description!.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade200),
                                              ),
                                              child: Text(
                                                pkg.description!,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade800,
                                                    height: 1.3),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ] else if (pkg.items.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade200),
                                              ),
                                              child: Text(
                                                pkg.items
                                                    .map((i) => '• ${i.name}')
                                                    .join('\n'),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade800,
                                                    height: 1.3),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],

                                          const Divider(height: 20),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              TextButton.icon(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pushNamed(
                                                  PackageDetailScreen.routeName,
                                                  arguments: pkg,
                                                ),
                                                icon: const Icon(
                                                    Icons.info_outline,
                                                    size: 16),
                                                label: const Text(
                                                    'Paket Detayı',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                              ),
                                              if (quantityInCart == 0)
                                                ElevatedButton.icon(
                                                  onPressed: () =>
                                                      cart.addPackage(pkg, shop,
                                                          quantity: 1),
                                                  icon: const Icon(
                                                      Icons.add_shopping_cart,
                                                      size: 16),
                                                  label: const Text(
                                                      'Sepete Ekle',
                                                      style: TextStyle(
                                                          fontSize: 12)),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    backgroundColor:
                                                        Theme.of(context)
                                                            .primaryColor,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 14,
                                                        vertical: 8),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8)),
                                                  ),
                                                )
                                              else
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.teal.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: Theme.of(context)
                                                            .primaryColor
                                                            .withValues(
                                                                alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        icon: const Icon(
                                                            Icons.remove,
                                                            size: 16),
                                                        onPressed: () =>
                                                            cart.decrementItem(
                                                                -pkg.id,
                                                                shop.id),
                                                      ),
                                                      Text('$quantityInCart',
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      14)),
                                                      IconButton(
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        icon: const Icon(
                                                            Icons.add,
                                                            size: 16),
                                                        onPressed: () =>
                                                            cart.incrementItem(
                                                                -pkg.id,
                                                                shop.id),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWhatsAppSingleOrderCard(Shop shop) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
      ),
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tekli Ürün Siparişi (Ekmek, İçecek vb.)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Paket dışındaki özel siparişleriniz için WhatsApp üzerinden dükkana doğrudan mesaj atabilirsiniz.',
              style: TextStyle(
                  fontSize: 12.5, color: Colors.grey.shade800, height: 1.3),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openWhatsAppForSingleItem(shop),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text(
                  'WhatsApp ile Tekli Sipariş Ver / Yaz',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
