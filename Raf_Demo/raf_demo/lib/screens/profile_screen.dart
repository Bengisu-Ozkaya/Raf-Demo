import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/shop_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Hem müşteri hem esnaf (satıcı) için profil görüntüleme ve düzenleme ekranı.
class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';
  final bool isEmbedded;

  const ProfileScreen({super.key, this.isEmbedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  String? _selectedCity;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final isMerchant =
        Provider.of<AuthProvider>(context, listen: false).userType ==
            UserType.merchant;

    _nameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(
        text: isMerchant
            ? (user?.username.isNotEmpty == true
                ? user!.username
                : user?.name ?? '')
            : (user?.username ?? ''));
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _selectedCity =
        (user?.city != null && user!.city.isNotEmpty) ? user.city : 'İstanbul';

    if (!TURKEY_CITIES.contains(_selectedCity)) {
      _selectedCity = TURKEY_CITIES.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _populateControllers(AppUser? user, bool isMerchant) {
    _nameController.text = user?.name ?? '';
    _usernameController.text = isMerchant
        ? (user?.username.isNotEmpty == true
            ? user!.username
            : user?.name ?? '')
        : (user?.username ?? '');
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phone ?? '';
    if (user?.city != null && TURKEY_CITIES.contains(user!.city)) {
      _selectedCity = user.city;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    final success = await authProvider.updateProfile(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      city: _selectedCity ?? 'İstanbul',
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      setState(() {
        _isEditing = false;
      });

      // Müşteri ise seçili şehri ve mağazaları da otomatik güncelle
      if (authProvider.userType == UserType.customer && _selectedCity != null) {
        shopProvider.selectCity(_selectedCity!);
        shopProvider.fetchShops();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil bilgileriniz başarıyla güncellendi.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ??
              'Profil güncellenirken hata oluştu.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final passwordFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppColors.taupe),
            SizedBox(width: 8),
            Text('Şifre Değiştir',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepEspresso)),
          ],
        ),
        content: Form(
          key: passwordFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mevcut Şifre',
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.taupe),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Lütfen mevcut şifrenizi girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre',
                  prefixIcon: Icon(Icons.lock, color: AppColors.taupe),
                ),
                validator: (val) {
                  if (val == null || val.length < 6) {
                    return 'Yeni şifre en az 6 karakter olmalıdır';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre (Tekrar)',
                  prefixIcon: Icon(Icons.lock_clock, color: AppColors.taupe),
                ),
                validator: (val) {
                  if (val != newPasswordController.text) {
                    return 'Şifreler eşleşmiyor';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal',
                style: TextStyle(color: AppColors.mochaText)),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordFormKey.currentState!.validate()) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Şifreniz başarıyla güncellendi.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.taupe,
              foregroundColor: Colors.white,
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.deepEspresso)),
        content: const Text(
            'Hesabınızdan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç',
                style: TextStyle(color: AppColors.mochaText)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isMerchant = authProvider.userType == UserType.merchant;

    final bodyContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profil Başlığı (Avatar & Bilgi Özeti)
              _buildHeaderCard(context, user, isMerchant),
              const SizedBox(height: 20),

              // 2. Profil Detay Kartı (Görüntüleme veya Düzenleme Formu)
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.7)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _isEditing
                      ? _buildEditForm(context, isMerchant)
                      : _buildViewDetails(context, user, isMerchant),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Hesap ve Güvenlik İşlemleri
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.7)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.cream,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline,
                            color: AppColors.taupe),
                      ),
                      title: const Text('Şifre Değiştir',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepEspresso)),
                      subtitle: const Text('Hesap güvenliğinizi güncelleyin',
                          style: TextStyle(color: AppColors.mochaText)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.mochaText),
                      onTap: _showChangePasswordDialog,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.exit_to_app,
                            color: AppColors.error),
                      ),
                      title: const Text('Çıkış Yap',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.error)),
                      subtitle: const Text('Oturumu sonlandır',
                          style: TextStyle(color: AppColors.mochaText)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.error),
                      onTap: () => _showLogoutConfirmation(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Düzenle',
              onPressed: () {
                _populateControllers(user, isMerchant);
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: bodyContent,
    );
  }

  /// Profil Başlık Kartı (Avatar, İsim, Rol, Şehir)
  Widget _buildHeaderCard(
      BuildContext context, AppUser? user, bool isMerchant) {
    final displayName = user?.name.isNotEmpty == true
        ? user!.name
        : (user?.username.isNotEmpty == true
            ? user!.username
            : (isMerchant ? 'İşletme' : 'Kullanıcı'));

    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.taupe,
            AppColors.deepEspresso,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepEspresso.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.cream,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.deepEspresso,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMerchant ? Icons.storefront : Icons.person,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMerchant ? 'İşletmeci Hesabı' : 'Müşteri Hesabı',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user?.city != null && user!.city.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: AppColors.deepEspresso),
                            const SizedBox(width: 2),
                            Text(
                              user.city,
                              style: const TextStyle(
                                color: AppColors.deepEspresso,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Profil Bilgileri Görüntüleme Modu
  Widget _buildViewDetails(
      BuildContext context, AppUser? user, bool isMerchant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kullanıcı Bilgileri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.deepEspresso,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.taupe),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Düzenle'),
              onPressed: () {
                _populateControllers(user, isMerchant);
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          icon: isMerchant ? Icons.store : Icons.person_outline,
          label: isMerchant ? 'İşletme / Dükkan Adı' : 'Kullanıcı Adı',
          value: user?.username.isNotEmpty == true
              ? user!.username
              : (user?.name ?? 'Belirtilmedi'),
        ),
        _buildInfoTile(
          icon: Icons.badge_outlined,
          label: isMerchant ? 'Yetkili / Sahip Adı' : 'Ad Soyad',
          value: user?.name.isNotEmpty == true ? user!.name : 'Belirtilmedi',
        ),
        _buildInfoTile(
          icon: Icons.email_outlined,
          label: 'E-Posta Adresi',
          value: user?.email.isNotEmpty == true ? user!.email : 'Belirtilmedi',
        ),
        _buildInfoTile(
          icon: Icons.phone_outlined,
          label: 'Telefon Numarası',
          value:
              user?.phone?.isNotEmpty == true ? user!.phone! : 'Belirtilmedi',
        ),
        _buildInfoTile(
          icon: Icons.location_city_outlined,
          label: 'Şehir',
          value: user?.city.isNotEmpty == true ? user!.city : 'Belirtilmedi',
        ),
        if (isMerchant && user?.id != null)
          _buildInfoTile(
            icon: Icons.numbers_outlined,
            label: 'Mağaza Numarası (ID)',
            value: '#${user!.id}',
          ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.taupe),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mochaText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepEspresso,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Profil Bilgileri Düzenleme Modu
  Widget _buildEditForm(BuildContext context, bool isMerchant) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bilgileri Düzenle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepEspresso,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.mochaText),
                tooltip: 'Vazgeç',
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ad Soyad / Yetkili Adı
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: isMerchant ? 'Yetkili Adı Soyadı' : 'Ad Soyad',
              prefixIcon:
                  const Icon(Icons.person_outline, color: AppColors.taupe),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bu alan boş bırakılamaz';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Kullanıcı Adı / Dükkan Adı
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: isMerchant ? 'Dükkan / Market Adı' : 'Kullanıcı Adı',
              prefixIcon: Icon(isMerchant ? Icons.store : Icons.alternate_email,
                  color: AppColors.taupe),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bu alan boş bırakılamaz';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // E-posta
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'E-Posta Adresi',
              prefixIcon:
                  const Icon(Icons.email_outlined, color: AppColors.taupe),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Geçerli bir e-posta adresi giriniz';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Telefon Numarası
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Telefon Numarası',
              prefixIcon:
                  const Icon(Icons.phone_outlined, color: AppColors.taupe),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Telefon numarası gereklidir';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Şehir Seçimi
          DropdownButtonFormField<String>(
            initialValue: _selectedCity,
            decoration: InputDecoration(
              labelText: 'Şehir',
              prefixIcon: const Icon(Icons.location_city_outlined,
                  color: AppColors.taupe),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.surfaceSubtle,
            ),
            items: TURKEY_CITIES.map((String city) {
              return DropdownMenuItem<String>(
                value: city,
                child: Text(city),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedCity = newValue;
                });
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen bir şehir seçin';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Butonlar: Kaydet & Vazgeç
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _isEditing = false;
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mochaText,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Vazgeç'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.taupe,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Değişiklikleri Kaydet',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
