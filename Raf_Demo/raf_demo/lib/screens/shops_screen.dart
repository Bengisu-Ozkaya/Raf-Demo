import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

import 'shop_detail_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import '../widgets/custom_badge.dart'; // Sepet ikonu için özel badge widget'ı
import '../utils/constants.dart';

class ShopsScreen extends StatefulWidget {
  static const routeName = '/shops';
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // --- YENİ: AKILLI BAŞLANGIÇ ---
      // Giriş yapan kullanıcının şehrini al.
      final userCity =
          Provider.of<AuthProvider>(context, listen: false).user?.city;
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      // Sağlayıcıdaki şehri kullanıcının şehri olarak ayarla ve o şehre göre dükkanları çek.
      shopProvider.selectCity(userCity ?? 'Tüm Şehirler');
      Provider.of<ShopProvider>(context, listen: false).fetchShops();
    });
  }

  // Yenileme fonksiyonu
  Future<void> _refreshShops(BuildContext context) async {
    await Provider.of<ShopProvider>(context, listen: false).fetchShops();
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context);
    final shops = shopProvider.shops;

    // Türkiye'nin tüm 81 ili + "Tüm Şehirler" seçeneği
    final List<String> cities = [
      'Tüm Şehirler',
      ...TURKEY_CITIES,
    ];

    // HATA DÜZELTME: Dropdown'ın değeri (selectedCity) her zaman items listesinde olmalıdır.
    final String currentCity = shopProvider.selectedCity;
    if (!cities.contains(currentCity)) {
      cities.insert(1, currentCity); // "Tüm Şehirler"den sonra ekle.
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağazalar'),
        actions: <Widget>[
          // YENİ: Siparişlerim sayfasına yönlendirme butonu
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Siparişlerim',
            onPressed: () =>
                Navigator.of(context).pushNamed(OrdersScreen.routeName),
          ),
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
          // Çıkış butonu
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama ve Filtreleme Barı
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Mağaza ara...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      shopProvider.searchShops(value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Şehir filtresi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: shopProvider.selectedCity,
                      icon: const Icon(Icons.location_city),
                      items:
                          cities.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          // Seçilen şehre göre dükkanları yeniden çek
                          shopProvider.selectCity(newValue);
                          shopProvider.fetchShops();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Dükkan Listesi
          Expanded(
            // Yükleme durumunu provider'dan alıyoruz.
            // Sadece ilk yüklemede (liste boşken) tam ekran gösterge gösterelim.
            child: shopProvider.isLoading && shops.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _refreshShops(context),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(10.0),
                      itemCount: shops.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3 / 2.5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (ctx, i) => Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              ShopDetailScreen.routeName,
                              arguments: shops[
                                  i], // Argüman olarak tüm Shop nesnesini gönder
                            );
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(15),
                                    topRight: Radius.circular(15),
                                  ),
                                  child: Hero(
                                    // Animasyonlu geçiş için Hero widget'ı
                                    tag: 'shop-logo-${shops[i].id}',
                                    child: Image.network(
                                      shops[i].imageUrl ??
                                          'https://via.placeholder.com/150',
                                      fit: BoxFit.cover,
                                      // Hata durumunda gösterilecek widget
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.store,
                                                  size: 50, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  shops[i].name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
