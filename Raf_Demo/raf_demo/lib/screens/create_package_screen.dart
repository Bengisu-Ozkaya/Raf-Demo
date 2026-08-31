import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';

class CreatePackageScreen extends StatefulWidget {
  static const routeName = '/create-package';

  const CreatePackageScreen({super.key});

  @override
  State<CreatePackageScreen> createState() => _CreatePackageScreenState();
}

class _CreatePackageScreenState extends State<CreatePackageScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController =
      TextEditingController(text: '10');

  final List<String> _quickTemplates = [
    '🥖 Temel Gıda Paketi\n• 2 Adet Ekmek\n• 1 Litre Süt\n• 15\'li Yumurta\n• 500g Beyaz Peynir',
    '🧀 Kahvaltılık Paketi\n• 1 Paket Kaşar Peyniri\n• 1 Paket Zeytin\n• 1 Kavanoz Reçel\n• 1 Paket Tereyağı',
    '🍎 Meyve & Sebze Paketi\n• 1 kg Domates\n• 1 kg Salatalık\n• 1 kg Elma\n• 1 kg Muz',
    '🧃 Atıştırmalık & İçecek Paketi\n• 2 Adet Soğuk İçecek\n• 1 Paket Çerez\n• 2 Paket Bisküvi',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    final lines = template.split('\n');
    final title =
        lines.first.replaceAll(RegExp(r'^[^\wğüşıöçĞÜŞİÖÇ]+'), '').trim();
    final content = lines.sublist(1).join('\n').trim();

    setState(() {
      _nameController.text = title;
      _contentController.text = content;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.orange.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2,
                            color: Colors.orange.shade800, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'İşletmenize özel hazır paket oluşturun. Müşterileriniz bu paketi tek tıkla sepetine ekleyebilir veya WhatsApp üzerinden sipariş verebilir.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade900,
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
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickTemplates.map((tmpl) {
                          final label = tmpl.split('\n').first;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ActionChip(
                              label: Text(label,
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.grey.shade300),
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

                // 3. Paket İçeriği
                TextFormField(
                  controller: _contentController,
                  maxLines: 5,
                  minLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Paket İçeriği & Detaylar *',
                    hintText:
                        'Paket içinde yer alan ürünleri ve miktarlarını yazın:\nÖrn:\n• 2 Adet Ekmek\n• 500g Kaşar Peyniri\n• 1 Litre Süt',
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 50.0),
                      child: Icon(Icons.format_list_bulleted),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Lütfen paket içeriğini yazınız.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 24),

                // Canlı Önizleme Kartı
                const Text(
                  'Müşteri Görünümü Önizlemesi:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey),
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
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

  Widget _buildPreviewCard() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Paket Adı';
    final content = _contentController.text.trim().isNotEmpty
        ? _contentController.text.trim()
        : 'Paket içeriği buraya gelecek...';
    final priceStr = _priceController.text.trim().isNotEmpty
        ? _priceController.text.trim().replaceAll(',', '.')
        : '0.00';
    final stockStr = _stockController.text.trim().isNotEmpty
        ? _stockController.text.trim()
        : '10';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
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
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2,
                      color: Colors.orange.shade900, size: 28),
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
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stok: $stockStr Adet',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: Text(
                    '$priceStr ₺',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'Paket İçeriği:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              content,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = authProvider.shopId;

    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Hata: İşletme kimliği bulunamadı.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final packageName = _nameController.text.trim();
    final packageContent = _contentController.text.trim();
    final price =
        double.tryParse(_priceController.text.trim().replaceAll(',', '.')) ??
            0.0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 10;

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
                Text('Paket oluşturuluyor...'),
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
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Hata: ${shopProvider.errorMessage ?? "Paket eklenemedi."}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
