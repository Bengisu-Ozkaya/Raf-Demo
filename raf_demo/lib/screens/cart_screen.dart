import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';

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
              child: Text(
                'Sepetiniz boş.',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: cartShops.length,
              itemBuilder: (ctx, i) {
                final shop = cartShops[i];
                final shopItems = shop.items.values.toList();
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      // Dükkan Başlığı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: Text(
                          shop.shopName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // O dükkana ait ürünler
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: shopItems.length,
                        itemBuilder: (ctx, j) {
                          final item = shopItems[j];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                item.imageUrl ??
                                    'https://via.placeholder.com/150',
                              ),
                              onBackgroundImageError: (_, __) {},
                            ),
                            title: Text(item.name),
                            subtitle:
                                Text('${item.price.toStringAsFixed(2)} TL'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () =>
                                      cart.decrementItem(item.id, shop.shopId),
                                ),
                                Text(
                                  item.quantity.toString(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    // Stok kontrolü burada da yapılabilir,
                                    // ancak provider zaten bu kontrolü yapıyor.
                                    cart.incrementItem(item.id, shop.shopId);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      // Sipariş tamamlama butonu
      bottomNavigationBar: cart.totalAmount > 0
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: cart.isLoading
                    ? null
                    : () => _showPaymentMethodSheet(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: cart.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Siparişi Tamamla (${cart.totalAmount.toStringAsFixed(2)} TL)',
                      ),
              ),
            )
          : null,
    );
  }

  /// Ödeme yöntemi seçim modal'ını gösteren fonksiyon.
  void _showPaymentMethodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ödeme Yöntemini Seçin',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.teal),
                title: const Text('Kapıda Kartla Ödeme'),
                onTap: () {
                  Navigator.of(ctx).pop(); // Modal'ı kapat
                  _completeOrder(context, 'Kapıda Kart');
                },
              ),
              ListTile(
                leading: const Icon(Icons.money, color: Colors.green),
                title: const Text('Kapıda Nakit Ödeme'),
                onTap: () {
                  Navigator.of(ctx).pop(); // Modal'ı kapat
                  _completeOrder(context, 'Kapıda Nakit');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// Siparişi oluşturan, sepeti temizleyen ve onay diyalogu gösteren fonksiyon.
  Future<void> _completeOrder(
      BuildContext context, String paymentMethod) async {
    // Hem CartProvider hem de AuthProvider'a ihtiyacımız var.
    final cart = Provider.of<CartProvider>(context, listen: false);

    // YENİ: Eğer zaten bir sipariş gönderiliyorsa, tekrar göndermeyi engelle.
    if (cart.isLoading) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    // Kullanıcının giriş yapıp yapmadığını kontrol et
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sipariş vermek için giriş yapmalısınız.')),
        );
      }
      return;
    }

    // Backend'e sipariş göndermek için DOĞRU fonksiyonu çağırıyoruz.
    final success = await cart.placeOrder(
      userId: user.id,
      userName: user.name,
      paymentMethod: paymentMethod,
    );

    // Sonuca göre başarı veya hata diyalogu göster
    if (context.mounted) {
      if (success) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sipariş Alındı! 🚀'),
            content: const Text(
                'Siparişiniz başarıyla oluşturuldu ve markete iletildi.'),
            actions: [
              TextButton(
                child: const Text('Harika!'),
                onPressed: () {
                  Navigator.of(ctx).popUntil((route) => route.isFirst);
                },
              )
            ],
          ),
          barrierDismissible: false,
        );
      } else {
        // Sipariş gönderme başarısız olursa hata diyalogu göster
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hata Oluştu'),
            content: Text(cart.errorMessage ??
                'Siparişiniz gönderilemedi. Lütfen tekrar deneyin.'),
            actions: [
              TextButton(
                child: const Text('Tamam'),
                onPressed: () => Navigator.of(ctx).pop(),
              )
            ],
          ),
        );
      }
    }
  }
}

/*
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final cartShops = cart.shops.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sepetim'),
      ),
      body: cartShops.isEmpty
          ? const Center(
              child: Text(
                'Sepetiniz boş.',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: cartShops.length,
              itemBuilder: (ctx, i) {
                final shop = cartShops[i];
                final shopItems = shop.items.values.toList();
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      // Dükkan Başlığı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: Text(
                          shop.shopName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // O dükkana ait ürünler
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: shopItems.length,
                        itemBuilder: (ctx, j) {
                          final item = shopItems[j];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                item.imageUrl ??
                                    'https://via.placeholder.com/150',
                              ),
                              onBackgroundImageError: (_, __) {},
                            ),
                            title: Text(item.name),
                            subtitle:
                                Text('${item.price.toStringAsFixed(2)} TL'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () =>
                                      cart.decrementItem(item.id, shop.shopId),
                                ),
                                Text(
                                  item.quantity.toString(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    // Stok kontrolü burada da yapılabilir,
                                    // ancak provider zaten bu kontrolü yapıyor.
                                    cart.incrementItem(item.id, shop.shopId);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      // Sipariş tamamlama butonu
      bottomNavigationBar: cart.totalAmount > 0
          ? Padding(
              padding: const EdgeInsets.all(12.0),
            )
          : null,
    );
*/
