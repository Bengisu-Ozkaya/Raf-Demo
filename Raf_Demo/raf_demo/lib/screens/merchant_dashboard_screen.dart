import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/shop_provider.dart';
import '../models/merchant_order.dart';
import '../models/shop_package.dart';
import '../screens/create_package_screen.dart';
import '../screens/package_detail_screen.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için

/// İşletmecinin ürünlerini ve siparişlerini yönettiği ana panel ekranı.
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
        shopProvider.fetchMerchantOrders(shopId),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopName = authProvider.user?.name ?? 'İşletme Paneli';
    final shopCity = authProvider.user?.city ?? '';

    final List<Widget> widgetOptions = <Widget>[
      _buildProductsTab(context),
      _buildOrdersTab(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shopName),
            if (shopCity.isNotEmpty)
              Text(
                shopCity,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
              ),
          ],
        ),
        actions: [
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
            icon: Icon(Icons.receipt),
            label: 'Gelen Siparişler',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'fab_package',
              onPressed: () {
                Navigator.of(context).pushNamed(CreatePackageScreen.routeName);
              },
              backgroundColor: Colors.orange.shade800,
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
                  Icon(Icons.inventory_2_outlined,
                      size: 72, color: Colors.orange.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Marketinizde Henüz Paket Yok',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İşletmenize özel adını, içeriğini ve fiyatını belirleyeceğiniz hazır paketler oluşturarak müşterilerinize sunun.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed(CreatePackageScreen.routeName);
                    },
                    icon: const Icon(Icons.inventory_2),
                    label: const Text('Paket Oluştur'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toplam ${shopProvider.merchantPackages.length} paket listeleniyor',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed(CreatePackageScreen.routeName);
                      },
                      icon: const Icon(Icons.add_box, size: 16),
                      label: const Text('Yeni Paket',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
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

  /// "Gelen Siparişler" sekmesinin içeriğini oluşturan widget (Mock Data).
  Widget _buildOrdersTab(BuildContext context) {
    // YENİ: Gerçek sipariş verilerini gösteren yapı
    return Consumer<ShopProvider>(
      builder: (ctx, shopProvider, _) {
        final orders = shopProvider.merchantOrders;

        if (shopProvider.isLoading && orders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orders.isEmpty) {
          return const Center(
            child: Text('Henüz gelen bir siparişiniz yok.',
                textAlign: TextAlign.center),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (ctx, i) => _MerchantOrderItemCard(order: orders[i]),
        );
      },
    );
  }
}

/// Gelen siparişleri gösteren açılır-kapanır kart
class _MerchantOrderItemCard extends StatelessWidget {
  // YENİ: _MerchantOrderItemCard
  final MerchantOrder order;

  const _MerchantOrderItemCard(
      {required this.order}); // YENİ: _MerchantOrderItemCard

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          child: Text(order.customerName.substring(0, 1)),
        ),
        title: Text(
          order.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR')
                  .format(order.orderDate),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            _StatusUpdateWidget(order: order),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${order.items.fold(0, (sum, i) => sum + i.quantity)} Ürün',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.teal.shade800),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ödeme Yöntemi: ${order.paymentMethod}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                const Text('Sipariş İçeriği:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text('• ${item.quantity}x  ${item.name}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500))),
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

/// Sipariş durumunu gösteren ve güncelleyen widget.
class _StatusUpdateWidget extends StatelessWidget {
  final MerchantOrder order;
  const _StatusUpdateWidget({required this.order});

  // Bir sonraki olası durumları döndüren yardımcı fonksiyon.
  List<String> _getNextStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'Bekleniyor': // YENİ: Bekleniyor durumundan sonraki adımlar
        return ['Hazırlanıyor', 'İptal Edildi'];
      case 'Hazırlanıyor':
        return ['Yola Çıktı', 'İptal Edildi'];
      case 'Yola Çıktı':
        return ['Teslim Edildi'];
      default: // 'Teslim Edildi' veya 'İptal Edildi' için yeni bir aksiyon yok.
        return [];
    }
  }

  // Duruma göre renk belirleyen yardımcı fonksiyon.
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Teslim Edildi':
        return Colors.green;
      case 'Yola Çıktı':
        return Colors.blue.shade700;
      case 'Hazırlanıyor':
        return Colors.orange.shade700;
      case 'İptal Edildi':
        return Colors.red;
      case 'Bekleniyor': // YENİ: Bekleniyor durumu için renk
        return Colors.grey.shade600;
      default: // Bilinmeyen durumlar için varsayılan renk
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextStatuses = _getNextStatuses(order.status);

    // Eğer değiştirilebilecek bir sonraki durum yoksa, sadece Chip göster.
    if (nextStatuses.isEmpty) {
      return Chip(
        label: Text(order.status,
            style: const TextStyle(
                color: Colors.white, fontSize: 10)), // Font boyutu küçültüldü
        backgroundColor: _getStatusColor(order.status),
        visualDensity: VisualDensity.compact,
      );
    }

    // Değiştirilebilecek durumlar varsa, PopupMenuButton göster.
    return PopupMenuButton<String>(
      onSelected: (String newStatus) {
        Provider.of<ShopProvider>(context, listen: false)
            .updateOrderStatus(order.id, newStatus);
      },
      itemBuilder: (BuildContext context) {
        return nextStatuses.map((String status) {
          return PopupMenuItem<String>(value: status, child: Text(status));
        }).toList();
      },
      child: Chip(
        label: Text(order.status,
            style: const TextStyle(
                color: Colors.white, fontSize: 10)), // Font boyutu küçültüldü
        backgroundColor: _getStatusColor(order.status),
        avatar: const Icon(Icons.touch_app, color: Colors.white, size: 16),
        visualDensity: VisualDensity.compact,
      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.inventory_2,
                        color: Colors.orange.shade800, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Stok: ${package.stock} Adet',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade300),
                    ),
                    child: Text(
                      '${package.totalPrice.toStringAsFixed(2)} ₺',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ),
                ],
              ),

              if (package.description != null &&
                  package.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  package.description!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const Divider(height: 18),
              // Alt Satır: Durum ve Aksiyonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_outlined,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 5),
                      Text(
                        'WhatsApp Siparişine Açık',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
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
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
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
                backgroundColor: Colors.red, foregroundColor: Colors.white),
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
