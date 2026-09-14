import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shop_package.dart';
import '../models/shop.dart';
import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';
import '../utils/theme.dart';

class PackageDetailScreen extends StatefulWidget {
  static const routeName = '/package-detail';

  const PackageDetailScreen({super.key});

  @override
  State<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<PackageDetailScreen> {
  late ShopPackage _package;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is ShopPackage) {
        _package = args;
      }
      _isInit = true;
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paketi Sil'),
        content: Text(
            '"${_package.name}" paketini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              final shopProvider =
                  Provider.of<ShopProvider>(context, listen: false);
              final shopId = authProvider.shopId;
              if (shopId != null) {
                await shopProvider.deletePackage(_package.id, shopId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Paket başarıyla silindi.'),
                        backgroundColor: AppColors.success),
                  );
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _addToCart() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final shop = Shop(
      id: _package.shopId,
      name: _package.shopName ?? 'Market',
      city: '',
      phone: _package.shopPhone,
    );

    cart.addPackage(_package, shop, quantity: 1);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${_package.name}" sepete eklendi!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Sepete Git',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pushNamed(CartScreen.routeName);
          },
        ),
      ),
    );
  }

  void _askViaWhatsApp() async {
    String rawPhone = _package.shopPhone ?? '';
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
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final message =
        'Merhaba ${_package.shopName ?? "Market"}! Raf uygulamasından "${_package.name}" (${_package.totalPrice.toStringAsFixed(2)} TL) paketi hakkında bilgi almak / sipariş vermek istiyorum.';
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
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isMerchant = authProvider.userType == UserType.merchant;
    final items = _package.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(_package.name),
        actions: [
          if (isMerchant)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Paketi Sil',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Paket Başlık ve Fiyat Kartı
                    Card(
                      elevation: 2,
                      shadowColor: AppColors.taupe.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.cream,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppColors.sand, width: 1.2),
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined,
                                      color: AppColors.deepEspresso, size: 30),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _package.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.deepEspresso,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (_package.stock > 0)
                                        Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: AppColors.success,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Stok: ${_package.stock} Adet',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.sand, width: 1.2),
                                  ),
                                  child: Text(
                                    '${_package.totalPrice.toStringAsFixed(2)} ₺',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepEspresso,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Paket İçeriği Bölümü
                    Card(
                      elevation: 1.5,
                      shadowColor: AppColors.taupe.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.format_list_bulleted,
                                    color: AppColors.taupe, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Paket İçeriği',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepEspresso,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: AppColors.border),
                            if (_package.description != null &&
                                _package.description!.isNotEmpty)
                              Text(
                                _package.description!,
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: AppColors.mochaText),
                              )
                            else if (items.isNotEmpty)
                              ...items.map((item) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          size: 16, color: AppColors.success),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.deepEspresso,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                            else
                              const Text(
                                'Bu paket için detaylı içerik açıklaması girilmemiş.',
                                style: TextStyle(
                                    color: AppColors.lightText, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. WhatsApp Danışma Butonu
                    if (!isMerchant)
                      OutlinedButton.icon(
                        onPressed: _askViaWhatsApp,
                        icon: const Icon(Icons.chat_bubble_outline,
                            color: Color(0xFF25D366)),
                        label: const Text(
                          'WhatsApp ile Bu Paketi Sor / Sipariş Ver',
                          style: TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF25D366), width: 1.5),
                          backgroundColor: const Color(0xFFF0FDF4),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                  ],
                ),
              ),

              // Müşteriler İçin Alt Bar (Sepete Ekle / - [Adet] +)
              if (!isMerchant)
                Consumer<CartProvider>(
                  builder: (ctx, cart, _) {
                    final packageKey = -_package.id;
                    final quantityInCart = cart.shops[_package.shopId]
                            ?.items[packageKey]?.quantity ??
                        0;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: const Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.taupe.withValues(alpha: 0.1),
                            offset: const Offset(0, -3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: quantityInCart == 0
                            ? ElevatedButton.icon(
                                onPressed: _addToCart,
                                icon: const Icon(Icons.add_shopping_cart,
                                    size: 20),
                                label: Text(
                                  'Sepete Ekle (${_package.totalPrice.toStringAsFixed(2)} ₺)',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.taupe,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(14),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove,
                                              size: 20,
                                              color: AppColors.deepEspresso),
                                          onPressed: () {
                                            cart.decrementItem(
                                                -_package.id, _package.shopId);
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: Text(
                                            '$quantityInCart',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: AppColors.deepEspresso),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add,
                                              size: 20,
                                              color: AppColors.deepEspresso),
                                          onPressed: () {
                                            cart.incrementItem(
                                                -_package.id, _package.shopId);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pushNamed(CartScreen.routeName);
                                      },
                                      icon: const Icon(
                                          Icons.shopping_cart_checkout,
                                          size: 20),
                                      label: const Text(
                                        'Sepete Git',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.taupe,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
