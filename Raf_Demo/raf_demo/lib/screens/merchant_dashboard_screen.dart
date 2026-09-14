import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/shop_provider.dart';
import '../models/shop_package.dart';
import '../screens/create_package_screen.dart';
import '../screens/package_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../utils/theme.dart';

/// İşletmecinin ürünlerini yönettiği ana panel ekranı.
class MerchantDashboardScreen extends StatefulWidget {
  static const routeName = '/merchant-dashboard';

  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  int _selectedIndex = 0;
  late Future<void> _fetchInitialDataFuture;

  @override
  void initState() {
    super.initState();
    final shopId = Provider.of<AuthProvider>(context, listen: false).shopId;
    if (shopId != null) {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      _fetchInitialDataFuture = Future.wait([
        shopProvider.fetchMerchantPackages(shopId),
        shopProvider.fetchMerchantProducts(shopId),
      ]);
    } else {
      _fetchInitialDataFuture = Future.value();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final shopName = authProvider.user?.name ?? 'İşletme Paneli';
    final shopCity = authProvider.user?.city ?? '';

    final List<Widget> widgetOptions = <Widget>[
      _buildProductsTab(context),
      const ProfileScreen(isEmbedded: true),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedIndex == 1 ? 'İşletme Profili' : shopName),
            if (shopCity.isNotEmpty && _selectedIndex != 1)
              Text(
                shopCity,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
              ),
          ],
        ),
        actions: [
          if (_selectedIndex != 1)
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Profilim',
              onPressed: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _fetchInitialDataFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: widgetOptions.elementAt(_selectedIndex),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Paketlerim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profilim',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.taupe,
        unselectedItemColor: AppColors.mochaText.withValues(alpha: 0.6),
        backgroundColor: Colors.white,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'fab_package',
              onPressed: () {
                Navigator.of(context).pushNamed(CreatePackageScreen.routeName);
              },
              backgroundColor: AppColors.taupe,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.inventory_2),
              label: const Text('Paket Oluştur',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  /// "Paketlerim" sekmesinin içeriğini oluşturan widget.
  Widget _buildProductsTab(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (ctx, shopProvider, _) {
        if (shopProvider.isLoading && shopProvider.merchantPackages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (shopProvider.merchantPackages.isEmpty) {
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
                    child: const Icon(Icons.inventory_2_outlined,
                        size: 64, color: AppColors.taupe),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Marketinizde Henüz Paket Yok',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepEspresso,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'İşletmenize özel adını, içeriğini ve fiyatını belirleyeceğiniz hazır paketler oluşturarak müşterilerinize sunun.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mochaText, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed(CreatePackageScreen.routeName);
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('İlk Paketi Oluştur'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.taupe,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.taupe,
          onRefresh: () async {
            final shopId =
                Provider.of<AuthProvider>(context, listen: false).shopId;
            if (shopId != null) {
              await Future.wait([
                Provider.of<ShopProvider>(context, listen: false)
                    .fetchMerchantPackages(shopId),
                Provider.of<ShopProvider>(context, listen: false)
                    .fetchMerchantProducts(shopId),
              ]);
            }
          },
          child: Column(
            children: [
              // Hızlı Paket Bilgi Çubuğu
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cream.withValues(alpha: 0.6),
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.8)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toplam ${shopProvider.merchantPackages.length} paket listeleniyor',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepEspresso),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.taupe,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed(CreatePackageScreen.routeName);
                      },
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text('Yeni Paket',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 80),
                  itemCount: shopProvider.merchantPackages.length,
                  itemBuilder: (ctx, i) {
                    final package = shopProvider.merchantPackages[i];
                    return _ShopPackageCard(package: package);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Paket listesindeki her bir paketi temsil eden kart widget'ı.
class _ShopPackageCard extends StatelessWidget {
  final ShopPackage package;

  const _ShopPackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = Provider.of<AuthProvider>(context, listen: false).shopId!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pushNamed(
            PackageDetailScreen.routeName,
            arguments: package,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Satır: Paket Adı ve Fiyat
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2,
                        color: AppColors.taupe, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepEspresso,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Stok: ${package.stock} Adet',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mochaText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${package.totalPrice.toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepEspresso,
                      ),
                    ),
                  ),
                ],
              ),

              if (package.description != null &&
                  package.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  package.description!,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.mochaText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const Divider(height: 20),
              // Alt Satır: Durum ve Aksiyonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.chat_outlined,
                          size: 16, color: AppColors.success),
                      SizedBox(width: 5),
                      Text(
                        'WhatsApp Siparişine Açık',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.taupe,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            PackageDetailScreen.routeName,
                            arguments: package,
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('İçerik',
                            style: TextStyle(fontSize: 12)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        tooltip: 'Paketi Sil',
                        onPressed: () => _confirmDeletePackage(context,
                            shopProvider, package.id, shopId, package.name),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePackage(BuildContext context, ShopProvider provider,
      int packageId, int shopId, String packageName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Paketi Sil'),
        content:
            Text('"$packageName" paketini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Sil'),
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.deletePackage(packageId, shopId);
            },
          ),
        ],
      ),
    );
  }
}
