import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../providers/cart_provider.dart';

class ProductGridItem extends StatelessWidget {
  final Product product;
  final Shop shop;

  const ProductGridItem({
    super.key,
    required this.product,
    required this.shop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Ürün Resmi
          Expanded(
            child: Image.network(
              product.imageUrl ?? 'https://via.placeholder.com/150',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) =>
                  const Icon(Icons.fastfood, color: Colors.grey, size: 50),
            ),
          ),
          // Ürün Adı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          // Stok ve Bilgi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (product.weightVolume != null && product.weightVolume!.isNotEmpty)
                  Text(
                    product.weightVolume!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  'Stok: ${product.stock ?? 0}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Sepete Ekle Butonu
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: (product.stock ?? 0) > 0
                  ? () {
                      Provider.of<CartProvider>(context, listen: false)
                          .addItem(product, shop);
                      // Kullanıcıya geri bildirim ver
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} sepete eklendi!'),
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'GERİ AL',
                            onPressed: () {
                              Provider.of<CartProvider>(context, listen: false)
                                  .decrementItem(product.id, shop.id);
                            },
                          ),
                        ),
                      );
                    }
                  : null, // Stok 0 ise onPressed null olur (buton disabled)
              icon: Icon((product.stock ?? 0) > 0
                  ? Icons.add_shopping_cart
                  : Icons.remove_shopping_cart_outlined),
              label: Text((product.stock ?? 0) > 0 ? 'Ekle' : 'Tükendi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: (product.stock ?? 0) > 0
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
