import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';

class AddProductFromCatalogScreen extends StatefulWidget {
  static const routeName =
      '/add-product-from-catalog'; // YENİ: Route adı eklendi
  const AddProductFromCatalogScreen({super.key});

  @override
  _AddProductFromCatalogScreenState createState() =>
      _AddProductFromCatalogScreenState();
}

class _AddProductFromCatalogScreenState
    extends State<AddProductFromCatalogScreen> {
  // --- STATE (DURUM) DEĞİŞKENLERİ ---

  // Kategoriler (Tümü seçeneği ile birlikte)
  final List<String> _categories = [
    "Tümü",
    "Temel Gıda",
    "Sıvı Yağ",
    "İçecek",
    "Unlu Mamüller",
    "Şarküteri & Kahvaltılık",
    "Et Ürünleri",
    "Bebek",
    "Temizlik",
    "Kişisel Bakım",
    "Gıda Dışı",
    "Evcil Hayvan"
  ];
  String _selectedCategory = "Tümü";

  @override
  void initState() {
    super.initState();
    // Provider'ı dinlemeden, sadece metodunu çağırmak için kullanıyoruz.
    // Ekran ilk açıldığında "Tümü" kategorisindeki ürünleri getir.
    // Ayrıca, dükkanın mevcut ürünlerini de tazeleyelim ki "Ekle"/"Güncelle" durumu doğru olsun.
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = Provider.of<AuthProvider>(context, listen: false).shopId;
    shopProvider.fetchMasterProductsByCategory(_selectedCategory);
    if (shopId != null) {
      shopProvider.fetchMerchantProducts(shopId);
    }
  }

  /// Kategori değiştirildiğinde sadece master ürünleri yükler.
  Future<void> _loadMasterProductsForCategory(String category) async {
    setState(() {
      _selectedCategory = category;
    });
    await Provider.of<ShopProvider>(context, listen: false)
        .fetchMasterProductsByCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalogdan Ürün Ekle'),
      ),
      body: Column(
        children: [
          _buildCategoryChips(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  /// Sayfa durumuna göre (loading, loaded, error) uygun widget'ı döndürür.
  Widget _buildBody(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (ctx, shopProvider, _) {
        if (shopProvider.isLoading && shopProvider.masterProducts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (shopProvider.errorMessage != null &&
            shopProvider.masterProducts.isEmpty) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Hata: ${shopProvider.errorMessage}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ));
        }

        if (shopProvider.masterProducts.isEmpty) {
          return const Center(
              child: Text('Bu kategoride gösterilecek ürün bulunamadı.'));
        }

        // Ürün grid'ini provider'dan gelen veriyle oluştur.
        return _buildProductGrid(shopProvider.masterProducts);
      },
    );
  }

  /// Yatayda kayan kategori seçme barını oluşturur.
  Widget _buildCategoryChips() {
    return Container(
      height: 50,
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: EdgeInsets.only(
                left: index == 0 ? 12 : 8,
                right: index == _categories.length - 1 ? 12 : 0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _loadMasterProductsForCategory(category);
                }
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              backgroundColor: Colors.white,
              shape: StadiumBorder(
                  side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!)),
            ),
          );
        },
      ),
    );
  }

  /// Ürünleri 2'li bir grid yapısında gösterir.
  Widget _buildProductGrid(List<Product> masterProducts) {
    // Dükkanın kendi ürünlerini de provider'dan alıyoruz.
    final merchantProducts =
        Provider.of<ShopProvider>(context, listen: true).merchantProducts;

    return RefreshIndicator(
      onRefresh: () => _loadMasterProductsForCategory(_selectedCategory),
      child: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.65, // Kartın en-boy oranını ayarlar
        ),
        itemCount: masterProducts.length,
        itemBuilder: (context, index) {
          final masterProduct = masterProducts[index];
          // Master ürüne karşılık gelen dükkan ürününü bul
          final shopProduct = merchantProducts.firstWhere(
            (p) => p.masterProductId == masterProduct.id,
            orElse: () => Product.empty(), // Bulunamazsa boş bir ürün döndür
          );
          return _buildProductCard(masterProduct, shopProduct);
        },
      ),
    );
  }

  /// Her bir ürün için gösterilecek kart widget'ını oluşturur.
  Widget _buildProductCard(Product masterProduct, Product shopProduct) {
    final isAdded = shopProduct.id != 0;

    return Card(
      elevation: 3,
      clipBehavior:
          Clip.antiAlias, // Görselin kart sınırlarından taşmasını engeller
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ürün Görseli
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.network(
                  masterProduct.imageUrl ?? '',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.inventory_2_outlined,
                      size: 50,
                      color: Colors.grey[400]),
                ),
              ),
            ),
          ),
          // Ürün Bilgileri
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    masterProduct.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${masterProduct.brand ?? ''} - ${masterProduct.weightVolume ?? ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (masterProduct.unitPrice != null && masterProduct.unitPrice! > 0)
                    Text(
                      'Birim Fiyat: ${masterProduct.unitPrice!.toStringAsFixed(2)} TL',
                      style: TextStyle(
                        color: Colors.blueGrey.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Ekle/Güncelle Butonu
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () =>
                  _showAddProductDialog(masterProduct, shopProduct),
              icon: Icon(isAdded ? Icons.edit : Icons.add_shopping_cart,
                  size: 16),
              label: Text(isAdded ? 'Güncelle' : 'Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdded
                    ? Colors.orange.shade700
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fiyat ve Stok girmek için diyalog penceresini gösterir.
  void _showAddProductDialog(Product masterProduct, Product shopProduct) {
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isAdded = shopProduct.id != 0;

    if (isAdded) {
      priceController.text =
          shopProduct.price?.toString() ?? '';
      stockController.text =
          shopProduct.stock?.toString() ?? '';
    } else if (masterProduct.unitPrice != null && masterProduct.unitPrice! > 0) {
      // Varsayılan olarak %25 kâr marjı ile fiyat öner
      final suggestedPrice = (masterProduct.unitPrice! * 1.25).toStringAsFixed(2);
      priceController.text = suggestedPrice;
      stockController.text = '10';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(masterProduct.name,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (masterProduct.unitPrice != null && masterProduct.unitPrice! > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Geliş Birim Fiyatı:', style: TextStyle(fontSize: 12)),
                          Text(
                            '${masterProduct.unitPrice!.toStringAsFixed(2)} TL',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                      labelText: 'Satış Fiyatı (TL)',
                      prefixIcon: Icon(Icons.price_change_outlined)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (v == null || v.isEmpty || double.tryParse(v) == null)
                          ? 'Geçerli bir fiyat girin'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: stockController,
                  decoration: const InputDecoration(
                      labelText: 'Stok Adedi',
                      prefixIcon: Icon(Icons.inventory_2_outlined)),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.isEmpty || int.tryParse(v) == null)
                          ? 'Geçerli bir stok girin'
                          : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                final price = double.parse(priceController.text);
                final stock = int.parse(stockController.text);

                Navigator.of(context).pop(); // Diyalogu hemen kapat

                // Provider üzerinden ürünü ekle/güncelle
                final shopProvider =
                    Provider.of<ShopProvider>(context, listen: false);
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                shopProvider
                    .addProduct(
                  masterProductId: masterProduct.id,
                  price: price,
                  stock: stock,
                  shopId: authProvider.shopId,
                )
                    .then((success) {
                  if (!mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Ürün başarıyla kaydedildi!'),
                        backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Hata: ${shopProvider.errorMessage ?? 'Ürün kaydedilemedi.'}'),
                        backgroundColor: Colors.red));
                  }
                });
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }
}
