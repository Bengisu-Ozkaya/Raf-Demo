import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/shop_provider.dart';
import '../models/merchant_order.dart';
import '../screens/add_product_from_catalog.dart'; // Yeni ekranı import et
import '../models/product.dart';
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
    // YENİ: Ekran ilk açıldığında hem ürünleri hem de siparişleri çek.
    // Ayrıca satıcıyı kendi özel sipariş odasına dahil et.
    final shopId = Provider.of<AuthProvider>(context, listen: false).shopId;
    if (shopId != null) {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      _fetchInitialDataFuture = Future.wait([
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
              // Giriş ekranına yönlendirme main.dart'taki Consumer tarafından otomatik yapılacak.
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
          return widgetOptions.elementAt(_selectedIndex);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Ürünlerim',
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
          ? FloatingActionButton(
              onPressed: () {
                // Katalogdan ürün ekleme ekranına yönlendir
                Navigator.of(context)
                    .pushNamed(AddProductFromCatalogScreen.routeName);
              },
              tooltip: 'Yeni Ürün Ekle',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// "Ürünlerim" sekmesinin içeriğini oluşturan widget.
  Widget _buildProductsTab(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (ctx, shopProvider, _) {
        if (shopProvider.isLoading && shopProvider.merchantProducts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (shopProvider.merchantProducts.isEmpty) {
          return const Center(
            child: Text(
                'Henüz hiç ürün eklemediniz.\nSağ alttaki (+) butonuyla başlayın.',
                textAlign: TextAlign.center),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final shopId =
                Provider.of<AuthProvider>(context, listen: false).shopId;
            await Provider.of<ShopProvider>(context, listen: false)
                .fetchMerchantProducts(shopId!);
          },
          child: ListView.builder(
            itemCount: shopProvider.merchantProducts.length,
            itemBuilder: (ctx, i) {
              final product = shopProvider.merchantProducts[i];
              return _ProductListItem(product: product);
            },
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
        trailing: Text(
          '${order.totalPrice.toStringAsFixed(2)} TL',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
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
                              child: Text('${item.quantity}x  ${item.name}')),
                          Text('${item.price.toStringAsFixed(2)} TL'),
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

/// Ürün listesindeki her bir elemanı temsil eden widget.
class _ProductListItem extends StatelessWidget {
  final Product product;

  const _ProductListItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = Provider.of<AuthProvider>(context, listen: false).shopId!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Ürün Bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${product.price?.toStringAsFixed(2) ?? '0.00'} TL',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Stok Kontrolü
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: (product.stock ?? 0) > 0
                      ? () => shopProvider.updateProduct(product.id, shopId,
                          stock: product.stock! - 1)
                      : null,
                ),
                Text((product.stock ?? 0).toString(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => shopProvider.updateProduct(
                      product.id, shopId,
                      stock: (product.stock ?? 0) + 1),
                ),
              ],
            ),
            // Silme Butonu
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(
                  context, shopProvider, product.id, shopId),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, ShopProvider provider, int productId, int shopId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: const Text(
            'Bu ürün kalıcı olarak silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.deleteProduct(productId, shopId);
            },
          ),
        ],
      ),
    );
  }
}
