import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../providers/cart_provider.dart';

/// Müşterinin gördüğü, bir dükkandaki tek bir ürünü temsil eden kart widget'ı.
/// Ürün görseli, adı, fiyatı ve en önemlisi stok durumunu gösterir.
class CustomerProductItem extends StatelessWidget {
  final Product product;
  final Shop shop;

  const CustomerProductItem({
    super.key,
    required this.product,
    required this.shop,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Card(
      clipBehavior:
          Clip.antiAlias, // Görselin kartın köşelerinden taşmasını engeller
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ürün görseli ve üzerinde stok bilgisi
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Ürün Görseli
                Image.network(
                  product.imageUrl ?? 'https://via.placeholder.com/300',
                  fit: BoxFit.cover,
                  // Yüklenirken gösterilecek placeholder
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  // Hata durumunda gösterilecek ikon
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported,
                        color: Colors.grey);
                  },
                ),
              ],
            ),
          ),
          // Ürün bilgileri ve Sepete Ekle butonu
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${product.price?.toStringAsFixed(2) ?? '0.00'} TL', // Null kontrolü eklendi
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (product.stock ?? 0) > 0 // Null kontrolü eklendi
                              ? 'Stok: ${product.stock}' // Null kontrolü eklendi
                              : 'Tükendi',
                          style: TextStyle(
                              fontSize: 12,
                              color: (product.stock ?? 0) > 0
                                  ? Colors.grey.shade600
                                  : Colors.red),
                        ),
                      ],
                    ),
                    // Stokta varsa sepete ekle butonu göster
                    if ((product.stock ?? 0) > 0) // Null kontrolü eklendi
                      IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        color: Theme.of(context).colorScheme.secondary,
                        onPressed: () {
                          cart.addItem(product, shop);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} sepete eklendi.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
