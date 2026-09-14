import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

import 'shop_detail_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import '../widgets/custom_badge.dart'; // Sepet ikonu için özel badge widget'ı
import '../utils/constants.dart';
import '../utils/theme.dart';

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
          // YENİ: Profilim sayfasına yönlendirme butonu
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profilim',
            onPressed: () =>
                Navigator.of(context).pushNamed(ProfileScreen.routeName),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Arama ve Filtreleme Barı
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Mağaza veya mahalle ara...',
                          prefixIcon:
                              const Icon(Icons.search, color: AppColors.taupe),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.taupe, width: 1.8),
                          ),
                        ),
                        onChanged: (value) {
                          shopProvider.searchShops(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Şehir filtresi
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.taupe.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: shopProvider.selectedCity,
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: AppColors.taupe),
                          items: cities
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 15, color: AppColors.taupe),
                                  const SizedBox(width: 5),
                                  Text(
                                    value,
                                    style: const TextStyle(
                                      color: AppColors.deepEspresso,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
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
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.taupe,
                        ),
                      )
                    : shops.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.cream,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.sand, width: 1.5),
                                    ),
                                    child: const Icon(
                                      Icons.storefront_outlined,
                                      size: 56,
                                      color: AppColors.taupe,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Bu Filtreye Uygun Mağaza Bulunamadı',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepEspresso,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Farklı bir şehir seçebilir veya arama kelimesini değiştirebilirsiniz.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.mochaText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.taupe,
                            onRefresh: () => _refreshShops(context),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: shops.length,
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 270,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemBuilder: (ctx, i) => Card(
                                elevation: 2,
                                shadowColor:
                                    AppColors.taupe.withValues(alpha: 0.15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color:
                                        AppColors.border.withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                      ShopDetailScreen.routeName,
                                      arguments: shops[i],
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Hero(
                                          tag: 'shop-logo-${shops[i].id}',
                                          child: (shops[i].imageUrl != null &&
                                                  shops[i].imageUrl!.isNotEmpty)
                                              ? Image.network(
                                                  shops[i].imageUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      _buildPlaceholderImage(),
                                                )
                                              : _buildPlaceholderImage(),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(12.0),
                                        color: Colors.white,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              shops[i].name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppColors.deepEspresso,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on,
                                                  size: 14,
                                                  color: AppColors.taupe,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    shops[i].city.isNotEmpty
                                                        ? shops[i].city
                                                        : 'Şehir belirtilmedi',
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color:
                                                          AppColors.mochaText,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cream, AppColors.sand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.taupe.withValues(alpha: 0.1),
                blurRadius: 6,
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            size: 38,
            color: AppColors.taupe,
          ),
        ),
      ),
    );
  }
}
