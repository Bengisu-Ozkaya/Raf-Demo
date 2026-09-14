import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../providers/cart_provider.dart';
import '../utils/theme.dart';

/// Müşterinin gördüğü, bir dükkandaki tek bir ürünü temsil eden kart widget'ı.
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
        children: [
          // Ürün görseli
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  product.imageUrl ?? 'https://via.placeholder.com/300',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppColors.cream,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.taupe,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.cream,
                      child: const Center(
                        child: Icon(Icons.shopping_bag_outlined,
                            color: AppColors.taupe, size: 36),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Ürün bilgileri ve Sepete Ekle butonu
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.deepEspresso,
                  ),
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
                        if (product.weightVolume != null &&
                            product.weightVolume!.isNotEmpty)
                          Text(
                            product.weightVolume!,
                            style: const TextStyle(
                              color: AppColors.mochaText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          (product.stock ?? 0) > 0
                              ? 'Stok: ${product.stock}'
                              : 'Tükendi',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: (product.stock ?? 0) > 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    // Stokta varsa sepete ekle butonu göster
                    if ((product.stock ?? 0) > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.sand, width: 1),
                        ),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          color: AppColors.deepEspresso,
                          onPressed: () {
                            cart.addItem(product, shop);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${product.name} sepete eklendi.'),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
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
