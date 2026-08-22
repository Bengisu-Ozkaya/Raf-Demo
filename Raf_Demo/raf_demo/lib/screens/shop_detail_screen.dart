import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop.dart';
import '../models/product.dart';
import '../models/shop_package.dart';
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
      _dataFuture = Future.wait([
        shopProvider.fetchPackages(shop.id),
        shopProvider.fetchMasterProducts(),
      ]);
      _isInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ModalRoute.of(context)!.settings.arguments as Shop;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(shop.name),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.inventory_2), text: '📦 Hazır Paketler'),
              Tab(icon: Icon(Icons.search), text: '🛍️ Tekli Ürünler'),
            ],
          ),
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
                final masterProducts = shopProvider.masterProducts;

                return TabBarView(
                  children: [
                    _PackagesTabView(packages: packages, shop: shop),
                    _SingleProductsTabView(masterProducts: masterProducts, shop: shop),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PackagesTabView extends StatefulWidget {
  final List<ShopPackage> packages;
  final Shop shop;

  const _PackagesTabView({required this.packages, required this.shop});

  @override
  State<_PackagesTabView> createState() => _PackagesTabViewState();
}

class _PackagesTabViewState extends State<_PackagesTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final packages = widget.packages;
    final shop = widget.shop;

    if (packages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.orange.shade300),
              const SizedBox(height: 16),
              const Text(
                'Henüz Hazır Paket Yok',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Consumer<CartProvider>(
          builder: (ctx, cart, _) {
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: packages.length,
              itemBuilder: (ctx, i) {
                final pkg = packages[i];
                final packageKey = -pkg.id;
                final quantityInCart = cart.shops[shop.id]?.items[packageKey]?.quantity ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pushNamed(PackageDetailScreen.routeName, arguments: pkg),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(pkg.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).pushNamed(PackageDetailScreen.routeName, arguments: pkg),
                                icon: const Icon(Icons.list_alt, size: 16),
                                label: const Text('Paket İçeriği', style: TextStyle(fontSize: 12)),
                              ),
                              if (quantityInCart == 0)
                                ElevatedButton.icon(
                                  onPressed: () => cart.addPackage(pkg, shop, quantity: 1),
                                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                                  label: const Text('Sepete Ekle', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 16), onPressed: () => cart.decrementItem(-pkg.id, shop.id)),
                                      Text('$quantityInCart', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 16), onPressed: () => cart.incrementItem(-pkg.id, shop.id)),
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
              },
            );
          },
        ),
      ),
    );
  }
}

class _SingleProductsTabView extends StatefulWidget {
  final List<Product> masterProducts;
  final Shop shop;

  const _SingleProductsTabView({required this.masterProducts, required this.shop});

  @override
  State<_SingleProductsTabView> createState() => _SingleProductsTabViewState();
}

class _SingleProductsTabViewState extends State<_SingleProductsTabView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedCategory = 'Tümü';
  String _searchQuery = '';
  final List<String> _categories = const ['Tümü', 'Temel Gıda', 'Atıştırmalık', 'İçecek', 'Temizlik', 'Kişisel Bakım', 'Bebek', 'Kahvaltılık & Soslar', 'Sıvı Yağ & Margarin', 'Ev & Yaşam'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = widget.masterProducts.where((p) {
      final matchesCategory = _selectedCategory == 'Tümü' || (p.category != null && p.category!.toLowerCase() == _selectedCategory.toLowerCase());
      final matchesSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Arama ve Kategori Filtreleri
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Ürün ara...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final cat = _categories[i];
                    final isSelected = cat == _selectedCategory;
                    return FilterChip(
                      selected: isSelected,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                        ),
                      ),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Ürün Sayısı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filtered.length} Ürün Listelendi',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // Ürünler Listesi
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Aranan kriterlere uygun ürün bulunamadı.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Consumer<CartProvider>(
                      builder: (ctx, cart, _) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final product = filtered[i];
                            final itemInCart = cart.shops[widget.shop.id]?.items[product.id];
                            final quantityInCart = itemInCart?.quantity ?? 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: quantityInCart > 0
                                      ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                                      : Colors.grey.shade200,
                                  width: quantityInCart > 0 ? 1.5 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                          ? Image.network(
                                              product.imageUrl!,
                                              fit: BoxFit.contain,
                                              cacheWidth: 120,
                                              cacheHeight: 120,
                                              errorBuilder: (ctx, e, st) =>
                                                  const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                            )
                                          : const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${product.brand ?? ''} ${product.weightVolume != null ? '• ${product.weightVolume}' : ''}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (quantityInCart == 0)
                                      ElevatedButton.icon(
                                        onPressed: () => cart.addItem(product, widget.shop, quantity: 1),
                                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                                        label: const Text('Sepete Ekle', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: Theme.of(context).primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              icon: const Icon(Icons.remove, size: 16),
                                              onPressed: () => cart.decrementItem(product.id, widget.shop.id),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              child: Text(
                                                '$quantityInCart',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              icon: const Icon(Icons.add, size: 16),
                                              onPressed: () => cart.incrementItem(product.id, widget.shop.id),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
