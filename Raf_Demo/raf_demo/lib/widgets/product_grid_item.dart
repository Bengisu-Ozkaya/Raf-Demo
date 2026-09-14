import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../providers/cart_provider.dart';
import '../utils/theme.dart';

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
    final hasStock = (product.stock ?? 0) > 0;

    return Card(
      elevation: 2,
      shadowColor: AppColors.taupe.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Ürün Resmi
          Expanded(
            child: Image.network(
              product.imageUrl ?? 'https://via.placeholder.com/150',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                color: AppColors.cream,
                child: const Center(
                  child: Icon(Icons.shopping_bag_outlined,
                      color: AppColors.taupe, size: 40),
                ),
              ),
            ),
          ),
          // Ürün Adı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              product.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: AppColors.deepEspresso,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          // Stok ve Bilgi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (product.weightVolume != null &&
                    product.weightVolume!.isNotEmpty)
                  Text(
                    product.weightVolume!,
                    style: const TextStyle(
                      color: AppColors.mochaText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  hasStock ? 'Stok: ${product.stock}' : 'Tükendi',
                  style: TextStyle(
                    color: hasStock ? AppColors.success : AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Sepete Ekle Butonu
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: hasStock
                  ? () {
                      Provider.of<CartProvider>(context, listen: false)
                          .addItem(product, shop);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} sepete eklendi!'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'GERİ AL',
                            textColor: Colors.white,
                            onPressed: () {
                              Provider.of<CartProvider>(context, listen: false)
                                  .decrementItem(product.id, shop.id);
                            },
                          ),
                        ),
                      );
                    }
                  : null,
              icon: Icon(
                hasStock
                    ? Icons.add_shopping_cart
                    : Icons.remove_shopping_cart_outlined,
                size: 16,
              ),
              label: Text(hasStock ? 'Ekle' : 'Tükendi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasStock ? AppColors.taupe : Colors.grey[300],
                foregroundColor: hasStock ? Colors.white : Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
