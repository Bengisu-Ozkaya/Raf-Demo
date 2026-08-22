import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';

enum PackageSize {
  small(name: 'Küçük Boy', minItems: 5, maxItems: 5, icon: Icons.inbox, color: Colors.teal),
  medium(name: 'Orta Boy', minItems: 8, maxItems: 10, icon: Icons.inventory_2, color: Colors.orange),
  large(name: 'Büyük Boy', minItems: 13, maxItems: 15, icon: Icons.all_inbox, color: Colors.purple);

  final String name;
  final int minItems;
  final int maxItems;
  final IconData icon;
  final MaterialColor color;

  const PackageSize({
    required this.name,
    required this.minItems,
    required this.maxItems,
    required this.icon,
    required this.color,
  });

  String get label => minItems == maxItems ? '$minItems Ürün' : '$minItems - $maxItems Ürün';
}

class CreatePackageScreen extends StatefulWidget {
  static const routeName = '/create-package';

  const CreatePackageScreen({super.key});

  @override
  State<CreatePackageScreen> createState() => _CreatePackageScreenState();
}

class _CreatePackageScreenState extends State<CreatePackageScreen> {
  PackageSize _selectedPackage = PackageSize.medium;
  final Set<int> _selectedMasterProductIds = {};

  final TextEditingController _packageNameController =
      TextEditingController(text: 'Orta Boy Paket');

  String _selectedCategory = 'Tümü';
  String _searchQuery = '';

  final List<String> _categories = [
    'Tümü',
    'Temel Gıda',
    'Atıştırmalık',
    'İçecek',
    'Temizlik',
    'Kişisel Bakım',
    'Bebek',
    'Kahvaltılık & Soslar',
    'Sıvı Yağ & Margarin',
    'Ev & Yaşam',
    'Evcil Hayvan',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ShopProvider>(context, listen: false).fetchMasterProductsByCategory('Tümü');
      }
    });
  }

  @override
  void dispose() {
    _packageNameController.dispose();
    super.dispose();
  }

  void _onPackageSizeChanged(PackageSize size) {
    setState(() {
      _selectedPackage = size;
      _packageNameController.text = '${size.name} Paket';
      if (_selectedMasterProductIds.length > size.maxItems) {
        final toRemove = _selectedMasterProductIds.toList().sublist(size.maxItems);
        _selectedMasterProductIds.removeAll(toRemove);
      }
    });
  }

  void _toggleProductSelection(Product product) {
    setState(() {
      if (_selectedMasterProductIds.contains(product.id)) {
        _selectedMasterProductIds.remove(product.id);
      } else {
        if (_selectedMasterProductIds.length >= _selectedPackage.maxItems) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedPackage.name} için en fazla ${_selectedPackage.maxItems} ürün seçebilirsiniz.'),
              backgroundColor: Colors.amber.shade900,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedMasterProductIds.add(product.id);
      }
    });
  }

  List<Product> _getFilteredProducts(List<Product> allProducts) {
    return allProducts.where((p) {
      final matchesCategory = _selectedCategory == 'Tümü' || p.category == _selectedCategory;
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          (p.brand != null && p.brand!.toLowerCase().contains(query)) ||
          (p.sapCode != null && p.sapCode!.contains(query));
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context);
    final masterProducts = shopProvider.masterProducts;
    final filteredProducts = _getFilteredProducts(masterProducts);

    final selectedProducts = masterProducts.where((p) => _selectedMasterProductIds.contains(p.id)).toList();

    final bool isCountValid = selectedProducts.length >= _selectedPackage.minItems &&
        selectedProducts.length <= _selectedPackage.maxItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paket Oluştur & Markete Ekle'),
        elevation: 1,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;

          if (isWide) {
            // Tablet / Masaüstü / Geniş Ekran Düzeni (2 Kolon)
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol Kolon: Filtreler ve Ürünler
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildPackageSizeSelector(),
                      _buildSearchBar(),
                      _buildCategoryFilter(),
                      _buildSelectionStatusBanner(selectedProducts.length),
                      Expanded(
                        child: _buildProductsView(
                          shopProvider: shopProvider,
                          masterProducts: masterProducts,
                          filteredProducts: filteredProducts,
                          isWide: true,
                          maxWidth: constraints.maxWidth,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sağ Kolon: Sabit Özet Paneli
                Container(
                  width: 360,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: _buildWideSidebar(
                    selectedCount: selectedProducts.length,
                    isValid: isCountValid,
                    selectedProducts: selectedProducts,
                  ),
                ),
              ],
            );
          } else {
            // Mobil Düzeni (Tek Kolon + Alt Panel)
            return Column(
              children: [
                _buildPackageSizeSelector(),
                _buildSearchBar(),
                _buildCategoryFilter(),
                _buildSelectionStatusBanner(selectedProducts.length),
                Expanded(
                  child: _buildProductsView(
                    shopProvider: shopProvider,
                    masterProducts: masterProducts,
                    filteredProducts: filteredProducts,
                    isWide: false,
                    maxWidth: constraints.maxWidth,
                  ),
                ),
                _buildMobileBottomCalculatorSheet(
                  selectedCount: selectedProducts.length,
                  isValid: isCountValid,
                  selectedProducts: selectedProducts,
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildProductsView({
    required ShopProvider shopProvider,
    required List<Product> masterProducts,
    required List<Product> filteredProducts,
    required bool isWide,
    required double maxWidth,
  }) {
    if (shopProvider.isLoading && masterProducts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filteredProducts.isEmpty) {
      return const Center(child: Text('Aradığınız kriterde ürün bulunamadı.'));
    }

    if (isWide && maxWidth >= 1100) {
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: filteredProducts.length,
        itemBuilder: (ctx, i) {
          final product = filteredProducts[i];
          final isSelected = _selectedMasterProductIds.contains(product.id);
          return _buildProductListTile(product, isSelected);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: filteredProducts.length,
      itemBuilder: (ctx, i) {
        final product = filteredProducts[i];
        final isSelected = _selectedMasterProductIds.contains(product.id);
        return _buildProductListTile(product, isSelected);
      },
    );
  }

  Widget _buildPackageSizeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Paket Boyutunu Seçin:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: PackageSize.values.map((size) {
              final isSelected = _selectedPackage == size;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onPackageSizeChanged(size),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? size.color.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? size.color : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(size.icon, color: isSelected ? size.color : Colors.grey, size: 22),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            size.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isSelected ? size.color.shade900 : Colors.black87,
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            size.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? size.color.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Ürün adı, marka veya SAP kodu ile ara...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
          fillColor: Colors.grey.shade100,
          filled: true,
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 42,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              selectedColor: _selectedPackage.color,
              backgroundColor: Colors.grey.shade100,
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = cat);
              },
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionStatusBanner(int selectedCount) {
    final bool isCompleted = selectedCount >= _selectedPackage.minItems && selectedCount <= _selectedPackage.maxItems;
    final int needed = _selectedPackage.minItems - selectedCount;

    return Container(
      width: double.infinity,
      color: isCompleted ? Colors.green.shade50 : Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.info_outline,
                  color: isCompleted ? Colors.green.shade700 : Colors.amber.shade800,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isCompleted
                        ? 'Hedef tamamlandı ($selectedCount ürün)'
                        : 'En az $needed ürün daha seçmelisiniz',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green.shade900 : Colors.amber.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.amber.shade800,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$selectedCount / ${_selectedPackage.maxItems}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListTile(Product product, bool isSelected) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      elevation: isSelected ? 2 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? _selectedPackage.color : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      color: isSelected ? _selectedPackage.color.shade50 : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _toggleProductSelection(product),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: isSelected ? _selectedPackage.color : Colors.grey.shade400,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (product.brand != null)
                          Flexible(
                            child: Text(
                              product.brand!,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (product.category != null) ...[
                          Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          Flexible(
                            child: Text(
                              product.category!,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (product.weightVolume != null && product.weightVolume!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    product.weightVolume!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Geniş Ekranlar için Sağ Sidebar
  Widget _buildWideSidebar({
    required int selectedCount,
    required bool isValid,
    required List<Product> selectedProducts,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_selectedPackage.icon, color: _selectedPackage.color),
              const SizedBox(width: 8),
              Text(
                '${_selectedPackage.name} Özeti',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hedef: ${_selectedPackage.label} (Seçilen: $selectedCount)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          // Paket Adı Giriş Alanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _packageNameController,
              decoration: const InputDecoration(
                labelText: 'Paket Adı',
                hintText: 'Örn: Temel Gıda Paketi',
                border: InputBorder.none,
                icon: Icon(Icons.edit_note, size: 20),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Seçilen Ürünler Başlığı
          Text(
            'Seçilen Ürünler ($selectedCount)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Seçilen Ürünler Listesi
          Expanded(
            child: selectedProducts.isEmpty
                ? Center(
                    child: Text(
                      'Soldaki listeden ürünleri seçmeye başlayın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: selectedProducts.length,
                    itemBuilder: (ctx, i) {
                      final p = selectedProducts[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.red),
                          onPressed: () => _toggleProductSelection(p),
                        ),
                      );
                    },
                  ),
          ),

          // Ekleme Butonu
          ElevatedButton.icon(
            onPressed: isValid ? () => _submitPackage(selectedProducts) : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(
              isValid
                  ? 'Paketi Markete Ekle ($selectedCount Ürün)'
                  : '${_selectedPackage.minItems} - ${_selectedPackage.maxItems} Ürün Seçin',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedPackage.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // Mobil Cihazlar için Alt Panel
  Widget _buildMobileBottomCalculatorSheet({
    required int selectedCount,
    required bool isValid,
    required List<Product> selectedProducts,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, -3),
            blurRadius: 8,
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mobil Paket Adı Girişi
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _packageNameController,
                  decoration: InputDecoration(
                    labelText: 'Paket Adı',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.edit_note, size: 18),
                  ),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedPackage.name}: $selectedCount / ${_selectedPackage.maxItems} Ürün',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isValid ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isValid ? () => _submitPackage(selectedProducts) : null,
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: Text(
                    isValid
                        ? 'Paketi Ekle ($selectedCount)'
                        : '${_selectedPackage.minItems}-${_selectedPackage.maxItems} Ürün Seçin',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedPackage.color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPackage(List<Product> selectedProducts) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = authProvider.shopId;

    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hata: İşletme kimliği bulunamadı.'), backgroundColor: Colors.red),
      );
      return;
    }

    final productsPayload = selectedProducts.map((p) {
      return {
        'master_product_id': p.id,
        'price': 0.0,
        'quantity': 1,
      };
    }).toList();

    final packageName = _packageNameController.text.trim().isNotEmpty
        ? _packageNameController.text.trim()
        : '${_selectedPackage.name} Paket';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Paket marketinize ekleniyor...'),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await shopProvider.createPackage(
      shopId: shopId,
      name: packageName,
      packageSize: _selectedPackage.name,
      totalPrice: 0.0,
      stock: 999,
      items: productsPayload,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 "$packageName" (${selectedProducts.length} ürün) başarıyla marketinize eklendi!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${shopProvider.errorMessage ?? "Paket eklenemedi."}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
