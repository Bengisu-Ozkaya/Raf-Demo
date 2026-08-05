import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop.dart';
import '../models/product.dart';
import '../providers/shop_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/custom_badge.dart';
import 'cart_screen.dart';

class ShopDetailScreen extends StatefulWidget {
  static const routeName = '/shop-detail';

  const ShopDetailScreen({super.key});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late Future<void> _productsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Argümanlardan gelen Shop nesnesini al
    final shop = ModalRoute.of(context)!.settings.arguments as Shop;
    // Sadece o dükkana ait ürünleri çekmek için future'ı başlat
    _productsFuture = Provider.of<ShopProvider>(context, listen: false)
        .fetchProductsForShop(shop.id);
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
        future: _productsFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          } else {
            return Consumer<ShopProvider>(
              builder: (ctx, shopProvider, _) {
                final products = shopProvider.products;
                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      'Bu mağazada henüz ürün bulunmuyor.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3 / 4, // Kart oranını ayarla
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (ctx, i) =>
                      _ProductGridItem(product: products[i], shop: shop),
                );
              },
            );
          }
        },
      ),
    );
  }
}

/// Ürün kartını temsil eden özel widget.
class _ProductGridItem extends StatefulWidget {
  final Product product;
  final Shop shop;

  const _ProductGridItem({required this.product, required this.shop});

  @override
  State<_ProductGridItem> createState() => _ProductGridItemState();
}

class _ProductGridItemState extends State<_ProductGridItem> {
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final itemInCart = cart.shops[widget.shop.id]?.items[widget.product.id];
    final quantityInCart = itemInCart?.quantity ?? 0;
    final bool isOutOfStock =
        (widget.product.stock ?? 0) <= 0; // Null kontrolü eklendi
    final bool isStockLimitReached =
        quantityInCart >= (widget.product.stock ?? 0); // Null kontrolü eklendi

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.network(
                widget.product.imageUrl ?? 'https://via.placeholder.com/150',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) =>
                    const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              widget.product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '${widget.product.price?.toStringAsFixed(2) ?? '0.00'} TL', // Null kontrolü eklendi
              style: TextStyle(
                  color: Theme.of(context).primaryColor, fontSize: 16),
            ),
          ),
          // Stok bilgisi eklendi
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
            child: Text(
              (widget.product.stock ?? 0) > 0 // Null kontrolü eklendi
                  ? 'Stok: ${widget.product.stock}' // Null kontrolü eklendi
                  : 'Tükendi',
              style: TextStyle(
                  // Null kontrolü eklendi
                  fontSize: 12, // Null kontrolü eklendi
                  color:
                      (widget.product.stock ?? 0) > 0 // Null kontrolü eklendi
                          ? Colors.grey.shade600
                          : Colors.red),
            ),
          ),
          // Adet artırma/azaltma ve sepete ekleme butonu
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: isOutOfStock
                ? ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      disabledForegroundColor:
                          Colors.white70.withValues(alpha: 0.38),
                      disabledBackgroundColor:
                          Colors.white70.withValues(alpha: 0.12),
                    ),
                    child: const Text('Tükendi'),
                  )
                : quantityInCart == 0
                    // Ürün sepette değilse: "Sepete Ekle" butonu
                    ? ElevatedButton(
                        onPressed: () {
                          // Buton callback'i içinde listen:false kullanmak best practice'dir.
                          Provider.of<CartProvider>(context, listen: false)
                              .addItem(widget.product, widget.shop,
                                  quantity: 1);
                        },
                        child: const Text('Sepete Ekle'),
                      )
                    // Ürün zaten sepetteyse: Mevcut adet kontrolleri
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              Provider.of<CartProvider>(context, listen: false)
                                  .decrementItem(
                                      widget.product.id, widget.shop.id);
                            },
                            color: Theme.of(context).primaryColor,
                          ),
                          Text(
                            quantityInCart.toString(),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: isStockLimitReached
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        // Null kontrolü eklendi
                                        content: Text(
                                            'Maksimum stok sınırına ulaştınız!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                : () {
                                    Provider.of<CartProvider>(context,
                                            listen: false)
                                        .incrementItem(
                                            widget.product.id, widget.shop.id,
                                            stockLimit: widget.product.stock ??
                                                0); // Null kontrolü eklendi
                                  },
                            color: isStockLimitReached
                                ? Colors.grey
                                : Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
