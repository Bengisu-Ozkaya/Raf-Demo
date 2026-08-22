import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shop_package.dart';
import '../models/shop.dart';
import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';

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
        content: Text('"${_package.name}" paketini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final shopProvider = Provider.of<ShopProvider>(context, listen: false);
              final shopId = authProvider.shopId;
              if (shopId != null) {
                await shopProvider.deletePackage(_package.id, shopId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paket başarıyla silindi.'), backgroundColor: Colors.green),
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
        content: Text('🎉 "${_package.name}" sepete eklendi!'),
        backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isMerchant = authProvider.userType == UserType.merchant;
    final items = _package.items;

    Color sizeColor;
    if (_package.packageSize.contains('Küçük')) {
      sizeColor = Colors.blue;
    } else if (_package.packageSize.contains('Orta')) {
      sizeColor = Colors.orange;
    } else {
      sizeColor = Colors.deepPurple;
    }

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
                    // 1. Paket Başlık Kartı
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _package.name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: sizeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${_package.packageSize} • ${items.length} Ürün',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: sizeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Paket Fiyatı', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      '${_package.totalPrice.toStringAsFixed(2)} TL',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Paket İçeriğindeki Ürünler Başlığı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paket İçeriği (${items.length} Çeşit Ürün)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // 3. Ürün Listesi
                    ...items.map((item) {
                      final unitPrice = item.unitPrice ?? 0.0;
                      final price = item.price ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Ürün Resmi
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        item.imageUrl!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (ctx, e, st) => const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                      )
                                    : const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                              ),
                              const SizedBox(width: 12),

                              // Ürün Bilgisi
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.brand ?? ''} ${item.weightVolume != null ? '• ${item.weightVolume}' : ''}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),

                              // Fiyat Bilgileri
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (isMerchant && unitPrice > 0)
                                    Text(
                                      'Maliyet: ${unitPrice.toStringAsFixed(2)} TL',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  Text(
                                    '${price.toStringAsFixed(2)} TL',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Müşteriler İçin Alt Bar (Sepete Ekle / - [Adet] +)
              if (!isMerchant)
                Consumer<CartProvider>(
                  builder: (ctx, cart, _) {
                    final packageKey = -_package.id;
                    final quantityInCart = cart.shops[_package.shopId]?.items[packageKey]?.quantity ?? 0;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x14000000),
                            offset: Offset(0, -3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: quantityInCart == 0
                            ? ElevatedButton.icon(
                                onPressed: _addToCart,
                                icon: const Icon(Icons.add_shopping_cart, size: 22),
                                label: const Text(
                                  'Sepete Ekle',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 20),
                                          onPressed: () {
                                            cart.decrementItem(-_package.id, _package.shopId);
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: Text(
                                            '$quantityInCart',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 20),
                                          onPressed: () {
                                            cart.incrementItem(-_package.id, _package.shopId);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(CartScreen.routeName);
                                      },
                                      icon: const Icon(Icons.shopping_cart_checkout, size: 20),
                                      label: const Text(
                                        'Sepete Git',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
