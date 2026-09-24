import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';

class CreatePackageScreen extends StatefulWidget {
  static const routeName = '/create-package';

  const CreatePackageScreen({super.key});

  @override
  State<CreatePackageScreen> createState() => _CreatePackageScreenState();
}

class _CreatePackageScreenState extends State<CreatePackageScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController =
      TextEditingController(text: '10');

  final List<TextEditingController> _itemControllers = [];
  final List<FocusNode> _itemFocusNodes = [];
  bool _itemsError = false;

  final List<String> _quickTemplates = [
    '🥖 Temel Gıda Paketi\n• 2 Adet Ekmek\n• 1 Litre Süt\n• 15\'li Yumurta\n• 500g Beyaz Peynir',
    '🧀 Kahvaltılık Paketi\n• 1 Paket Kaşar Peyniri\n• 1 Paket Zeytin\n• 1 Kavanoz Reçel\n• 1 Paket Tereyağı',
    '🍎 Meyve & Sebze Paketi\n• 1 kg Domates\n• 1 kg Salatalık\n• 1 kg Elma\n• 1 kg Muz',
    '🧃 Atıştırmalık & İçecek Paketi\n• 2 Adet Soğuk İçecek\n• 1 Paket Çerez\n• 2 Paket Bisküvi',
  ];

  @override
  void initState() {
    super.initState();
    // Başlangıçta kullanıcıya 2 adet boş madde satırı sunuyoruz
    _addItem(text: '');
    _addItem(text: '');
  }

  void _onItemsChanged() {
    setState(() {
      if (_itemsError && _getNonEmptyItems().isNotEmpty) {
        _itemsError = false;
      }
    });
  }

  void _addItem({String text = '', int? atIndex}) {
    final controller = TextEditingController(text: text);
    final focusNode = FocusNode();
    controller.addListener(_onItemsChanged);

    setState(() {
      _itemsError = false;
      if (atIndex != null &&
          atIndex >= 0 &&
          atIndex < _itemControllers.length) {
        _itemControllers.insert(atIndex + 1, controller);
        _itemFocusNodes.insert(atIndex + 1, focusNode);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            focusNode.requestFocus();
          }
        });
      } else {
        _itemControllers.add(controller);
        _itemFocusNodes.add(focusNode);
        if (text.isEmpty && _itemControllers.length > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              focusNode.requestFocus();
            }
          });
        }
      }
    });
  }

  void _removeItem(int index) {
    if (index < 0 || index >= _itemControllers.length) return;
    setState(() {
      if (_itemControllers.length == 1) {
        // Tek madde kaldıysa tamamen silmek yerine alanını temizle
        _itemControllers[0].clear();
        return;
      }
      final controller = _itemControllers.removeAt(index);
      final focusNode = _itemFocusNodes.removeAt(index);
      controller.dispose();
      focusNode.dispose();

      final nextFocusIndex = (index - 1).clamp(0, _itemFocusNodes.length - 1);
      if (_itemFocusNodes.isNotEmpty) {
        _itemFocusNodes[nextFocusIndex].requestFocus();
      }
    });
  }

  void _clearAndSetItems(List<String> items) {
    for (final c in _itemControllers) {
      c.dispose();
    }
    for (final f in _itemFocusNodes) {
      f.dispose();
    }
    _itemControllers.clear();
    _itemFocusNodes.clear();

    for (final item in items) {
      final controller = TextEditingController(text: item);
      final focusNode = FocusNode();
      controller.addListener(_onItemsChanged);
      _itemControllers.add(controller);
      _itemFocusNodes.add(focusNode);
    }
    if (_itemControllers.isEmpty) {
      _addItem(text: '');
    }
    setState(() {
      _itemsError = false;
    });
  }

  void _applyTemplate(String template) {
    final lines = template.split('\n');
    final title =
        lines.first.replaceAll(RegExp(r'^[^\wğüşıöçĞÜŞİÖÇ]+'), '').trim();
    final rawItems = lines.sublist(1);
    final cleanItems = rawItems
        .map((l) => l.replaceAll(RegExp(r'^[•\-\*\s]+'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    _nameController.text = title;
    _clearAndSetItems(cleanItems);
  }

  List<String> _getNonEmptyItems() {
    if (_itemControllers.isEmpty) return [];
    return _itemControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  String _getFormattedContent() {
    final validItems = _getNonEmptyItems();
    return validItems.map((item) => '• $item').join('\n');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    for (final f in _itemFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_itemControllers.isEmpty) {
      _addItem(text: '');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Paket Oluştur'),
        elevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Bilgi Kartı
                Card(
                  color: AppColors.cream,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2,
                            color: AppColors.taupe, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'İşletmenize özel hazır paket oluşturun. Müşterileriniz bu paketi tek tıkla sepetine ekleyebilir veya WhatsApp üzerinden sipariş verebilir.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.deepEspresso,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Hazır Şablonlar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hızlı Şablonlar (İsteğe Bağlı):',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.mochaText),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickTemplates.map((tmpl) {
                          final label = tmpl.split('\n').first;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ActionChip(
                              label: Text(label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.deepEspresso)),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              onPressed: () => _applyTemplate(tmpl),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 1. Paket Adı
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Paket Adı *',
                    hintText: 'Örn: Kahvaltılık Paketi, Günlük İhtiyaç Paketi',
                    prefixIcon: const Icon(Icons.edit_note),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Lütfen paket adını giriniz.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 16),

                // 2. Paket Fiyatı ve Stok
                Row(
                  children: [
                    // Fiyat
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+[\.,]?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Paket Fiyatı (₺) *',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.currency_lira),
                          suffixText: 'TL',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Fiyat giriniz.';
                          }
                          final parsed =
                              double.tryParse(val.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) {
                            return 'Geçerli fiyat girin.';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Stok
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Stok Adedi *',
                          hintText: '10',
                          prefixIcon: const Icon(Icons.inventory),
                          suffixText: 'Adet',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Stok giriniz.';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Paket İçeriği (Dinamik Checklist)
                _buildItemsChecklistSection(),

                const SizedBox(height: 24),

                // Canlı Önizleme Kartı
                const Text(
                  'Müşteri Görünümü Önizlemesi:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.mochaText),
                ),
                const SizedBox(height: 8),
                _buildPreviewCard(),

                const SizedBox(height: 24),

                // Kaydet & Yayınla Butonu
                ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Paketi Oluştur ve Marketime Ekle',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.taupe,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Her ürünün ayrı bir madde olduğu, Enter ile otomatik alt satıra geçilen checklist widget'ı
  Widget _buildItemsChecklistSection() {
    final nonEmptyCount = _getNonEmptyItems().length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _itemsError ? AppColors.error : AppColors.border,
          width: _itemsError ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.taupe.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Sayaç
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: AppColors.taupe,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paket İçeriği (Ürün Listesi) *',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepEspresso,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Klavyeden "Enter" veya "İleri"ye basarak otomatik yeni madde açabilirsiniz.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mochaText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sand.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.taupe.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '$nonEmptyCount Ürün',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepEspresso,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // Liste Satırları
          ...List.generate(_itemControllers.length, (index) {
            final isFilled = _itemControllers[index].text.trim().isNotEmpty;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  // Checkbox Görünümlü Madde İkonu
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color:
                          isFilled ? AppColors.taupe : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isFilled
                            ? AppColors.taupe
                            : AppColors.taupe.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: isFilled
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    AppColors.mochaText.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),

                  // Ürün Giriş Alanı
                  Expanded(
                    child: TextFormField(
                      controller: _itemControllers[index],
                      focusNode: _itemFocusNodes[index],
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        // Enter/İleri tuşuna basıldığında bir sonraki satırı otomatik aç
                        _addItem(atIndex: index);
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.deepEspresso,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: index == 0
                            ? 'Örn: 2 Adet Ekmek'
                            : index == 1
                                ? 'Örn: 1 Litre Süt'
                                : 'Ürün adı ve miktarını yazın...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.mochaText.withValues(alpha: 0.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor:
                            AppColors.surfaceSubtle.withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.taupe,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Satırı Sil Butonu
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: _itemControllers.length > 1 || isFilled
                          ? AppColors.mochaText
                          : Colors.transparent,
                    ),
                    tooltip: 'Ürünü Çıkar',
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: _itemControllers.length > 1 || isFilled
                        ? () => _removeItem(index)
                        : null,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          // Yeni Ürün / Madde Ekle Butonu
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _addItem(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.taupe.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 18, color: AppColors.taupe),
                  SizedBox(width: 8),
                  Text(
                    'Yeni Ürün / Madde Ekle (veya Enter\'a bas)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepEspresso,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_itemsError) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                SizedBox(width: 6),
                Text(
                  'Lütfen paket için en az bir ürün maddesi giriniz.',
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Paket Adı';
    final items = _getNonEmptyItems();
    final priceStr = _priceController.text.trim().isNotEmpty
        ? _priceController.text.trim().replaceAll(',', '.')
        : '0.00';
    final stockStr = _stockController.text.trim().isNotEmpty
        ? _stockController.text.trim()
        : '10';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2,
                      color: AppColors.taupe, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepEspresso,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stok: $stockStr Adet',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.mochaText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$priceStr ₺',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepEspresso,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Paket İçeriği:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mochaText),
                ),
                Text(
                  '${items.length} Kalem Ürün',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mochaText),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Paket içeriği ürünleri yukarıdaki listeden ekleyebilirsiniz...',
                  style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.mochaText),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.sand.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 11,
                            color: AppColors.deepEspresso,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.deepEspresso,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final items = _getNonEmptyItems();
    if (items.isEmpty) {
      setState(() {
        _itemsError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Lütfen paket içeriğine en az bir ürün maddesi ekleyin.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = authProvider.shopId;

    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Hata: İşletme kimliği bulunamadı.'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final packageName = _nameController.text.trim();
    final packageContent = _getFormattedContent();
    final price =
        double.tryParse(_priceController.text.trim().replaceAll(',', '.')) ??
            0.0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 10;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.taupe),
                SizedBox(height: 16),
                Text('Paket oluşturuluyor...',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await shopProvider.createPackage(
      shopId: shopId,
      name: packageName,
      description: packageContent,
      packageSize:
          packageContent.isNotEmpty ? packageContent : 'Standart Paket',
      totalPrice: price,
      stock: stock,
      items: const [],
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Loading dialogunu kapat

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$packageName" paketi başarıyla marketinize eklendi!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Hata: ${shopProvider.errorMessage ?? "Paket eklenemedi."}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
