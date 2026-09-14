import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

// Auth modunu (Giriş veya Kayıt) belirlemek için enum
enum AuthMode { Login, Register }

class AuthScreen extends StatefulWidget {
  static const routeName = '/auth';

  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Giriş formunun state'ini yönetmek için GlobalKey
  final _formKey = GlobalKey<FormState>();

  // Text-field controller'ları. Kayıt için yeni controller'lar eklendi.
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Şifre görünürlüğü kontrolleri
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // --- YENİ: Dükkan Sahibi için Controller'lar ---
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  String? _selectedCity; // Dükkanın şehri için

  // Mevcut auth modunu tutar
  AuthMode _authMode = AuthMode.Login;

  // "Müşteriyim" / "Satıcıyım" seçimi için
  UserType _userType = UserType.customer;

  // Türkiye'deki tüm iller (81 il)
  final List<String> _cities = TURKEY_CITIES;

  // Hata mesajlarını göstermek için
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bir Hata Oluştu'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Tamam'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  // Giriş yapma fonksiyonu
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return; // Form geçerli değilse devam etme
    }
    _formKey.currentState!.save();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (_userType == UserType.customer) {
        // --- MÜŞTERİ İŞLEMLERİ ---
        if (_authMode == AuthMode.Login) {
          final success = await authProvider.login(
            _identifierController.text.trim(),
            _passwordController.text.trim(),
            UserType.customer,
          );
          // Başarılı giriş sonrası yönlendirme main.dart'taki Consumer tarafından yapılacak.
          // Biz burada sadece başarısızlık durumunu ele alıyoruz.
          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(authProvider.errorMessage ?? 'Giriş başarısız.'),
                backgroundColor: Theme.of(context).colorScheme.error));
          }
        } else {
          // Müşteri Kayıt
          final success = await authProvider.register(
            username: _identifierController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text.trim(),
            city: _selectedCity!,
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Kayıt başarılı! Lütfen giriş yapın.'),
              backgroundColor: AppColors.success,
            ));
            _switchAuthMode();
          } else if (mounted) {
            _showErrorDialog(authProvider.errorMessage ?? 'Kayıt başarısız.');
          }
        }
      } else {
        // --- DÜKKAN SAHİBİ İŞLEMLERİ ---
        if (_authMode == AuthMode.Login) {
          final success = await authProvider.login(
            // KRİTİK DÜZELTME: Satıcı girişi için doğru controller (_phoneController) kullanılıyor.
            _phoneController.text.trim(),
            _passwordController.text.trim(),
            UserType.merchant,
          );
          // Başarılı giriş sonrası yönlendirme main.dart'taki Consumer tarafından yapılacak.
          // Biz burada sadece başarısızlık durumunu ele alıyoruz.
          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(authProvider.errorMessage ?? 'Giriş başarısız.'),
                backgroundColor: Theme.of(context).colorScheme.error));
          }
        } else {
          // Dükkan Kayıt
          if (_selectedCity == null) {
            _showErrorDialog('Lütfen dükkanınızın bulunduğu şehri seçin.');
            return;
          }
          final success = await authProvider.registerMerchant(
            shopName: _shopNameController.text.trim(),
            ownerName: _ownerNameController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text.trim(),
            city: _selectedCity!,
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Dükkan kaydı başarılı! Lütfen giriş yapın.'),
              backgroundColor: AppColors.success,
            ));
            _switchAuthMode();
          } else if (mounted) {
            _showErrorDialog(authProvider.errorMessage ?? 'Kayıt başarısız.');
          }
        }
      }
    } catch (error) {
      _showErrorDialog(error.toString());
    }
  }

  // Giriş ve Kayıt modları arasında geçiş yapar
  void _switchAuthMode() {
    setState(() {
      if (_authMode == AuthMode.Login) {
        _authMode = AuthMode.Register;
      } else {
        _authMode = AuthMode.Login;
      }
      _formKey.currentState?.reset(); // Formu temizle
      // Controller'ları da temizleyelim
      _identifierController.clear();
      _passwordController.clear();
      _emailController.clear();
      _phoneController.clear();
      _confirmPasswordController.clear();
      _shopNameController.clear();
      _ownerNameController.clear();
      _selectedCity = null;
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _confirmPasswordController.dispose();
    _shopNameController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.cream],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Marka ve Logo Başlığı
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.sand, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.taupe.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 42,
                          color: AppColors.deepEspresso,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Raf',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: AppColors.deepEspresso,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _authMode == AuthMode.Login
                          ? 'Mahallenizin taze ürünleri ve esnaf rafları'
                          : 'Yeni bir hesap oluşturarak mahalleye katılın',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.mochaText,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Giriş / Kayıt Kartı
                    Card(
                      elevation: 3,
                      shadowColor: AppColors.taupe.withValues(alpha: 0.18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side:
                            const BorderSide(color: AppColors.border, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              // Başlık
                              Text(
                                _authMode == AuthMode.Login
                                    ? 'Giriş Yap'
                                    : 'Hesap Oluştur',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepEspresso,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Müşteri / Satıcı Rol Seçici (Hem Giriş hem Kayıt için)
                              SegmentedButton<UserType>(
                                segments: const <ButtonSegment<UserType>>[
                                  ButtonSegment<UserType>(
                                    value: UserType.customer,
                                    label: Text('Müşteriyim'),
                                    icon: Icon(Icons.person_outline, size: 18),
                                  ),
                                  ButtonSegment<UserType>(
                                    value: UserType.merchant,
                                    label: Text('Satıcıyım'),
                                    icon: Icon(Icons.storefront_outlined,
                                        size: 18),
                                  ),
                                ],
                                selected: <UserType>{_userType},
                                onSelectionChanged:
                                    (Set<UserType> newSelection) {
                                  setState(() {
                                    _userType = newSelection.first;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),

                              // --- DİNAMİK FORM ALANLARI ---

                              // Müşteri Giriş/Kayıt için Kullanıcı Adı/E-posta
                              if (_userType == UserType.customer)
                                TextFormField(
                                  controller: _identifierController,
                                  decoration: InputDecoration(
                                    labelText: _authMode == AuthMode.Login
                                        ? 'E-posta veya Kullanıcı Adı'
                                        : 'Kullanıcı Adı',
                                    prefixIcon: const Icon(
                                        Icons.account_circle_outlined),
                                  ),
                                  keyboardType: TextInputType.text,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Lütfen bu alanı doldurun.';
                                    }
                                    return null;
                                  },
                                ),

                              // Dükkan Kayıt için Dükkan Adı
                              if (_userType == UserType.merchant &&
                                  _authMode == AuthMode.Register) ...[
                                TextFormField(
                                  controller: _shopNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Market / Dükkan Adı',
                                    prefixIcon: Icon(Icons.storefront_rounded),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Lütfen market adını girin.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Dükkan Kayıt için Sahip Adı
                              if (_userType == UserType.merchant &&
                                  _authMode == AuthMode.Register) ...[
                                TextFormField(
                                  controller: _ownerNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Dükkan Sahibi (Ad Soyad)',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Lütfen adınızı ve soyadınızı girin.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Müşteri Kayıt için E-posta
                              if (_userType == UserType.customer &&
                                  _authMode == AuthMode.Register) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'E-posta Adresi',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || !value.contains('@')) {
                                      return 'Lütfen geçerli bir e-posta adresi girin.';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              // Müşteri Kayıt için Şehir Seçimi
                              if (_userType == UserType.customer &&
                                  _authMode == AuthMode.Register) ...[
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCity,
                                  decoration: const InputDecoration(
                                    labelText: 'Şehir',
                                    prefixIcon:
                                        Icon(Icons.location_city_outlined),
                                  ),
                                  hint: const Text('Şehir Seçin'),
                                  items: _cities.map((String city) {
                                    return DropdownMenuItem<String>(
                                      value: city,
                                      child: Text(city),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      _selectedCity = newValue;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Lütfen bir şehir seçin.';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              // Telefon Numarası (Kayıt) veya Tanımlayıcı (Dükkan Giriş)
                              if ((_userType == UserType.customer &&
                                      _authMode == AuthMode.Register) ||
                                  _userType == UserType.merchant) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: InputDecoration(
                                    labelText: _userType == UserType.merchant &&
                                            _authMode == AuthMode.Login
                                        ? 'Market Adı veya Telefon No'
                                        : 'Telefon Numarası',
                                    prefixIcon: Icon(
                                        _userType == UserType.merchant &&
                                                _authMode == AuthMode.Login
                                            ? Icons.store
                                            : Icons.phone_outlined),
                                  ),
                                  keyboardType: _authMode == AuthMode.Register
                                      ? TextInputType.phone
                                      : TextInputType.text,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Lütfen bu alanı doldurun.';
                                    }
                                    if (_authMode == AuthMode.Register &&
                                        value.length < 10) {
                                      return 'Lütfen geçerli bir telefon numarası girin.';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              // Dükkan Kayıt için Şehir Seçimi
                              if (_userType == UserType.merchant &&
                                  _authMode == AuthMode.Register) ...[
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCity,
                                  decoration: const InputDecoration(
                                    labelText: 'Şehir',
                                    prefixIcon:
                                        Icon(Icons.location_city_outlined),
                                  ),
                                  hint: const Text('Şehir Seçin'),
                                  items: _cities.map((String city) {
                                    return DropdownMenuItem<String>(
                                      value: city,
                                      child: Text(city),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      _selectedCity = newValue;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Lütfen bir şehir seçin.';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              const SizedBox(height: 14),

                              // Şifre alanı
                              TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Şifre',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.mochaText,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null ||
                                      value.isEmpty ||
                                      value.length < 6) {
                                    return 'Şifre en az 6 karakter olmalıdır.';
                                  }
                                  return null;
                                },
                              ),

                              // Şifre Tekrar alanı (sadece kayıt modunda)
                              if (_authMode == AuthMode.Register) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: InputDecoration(
                                    labelText: 'Şifreyi Onayla',
                                    prefixIcon: const Icon(Icons.lock_reset),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppColors.mochaText,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                  ),
                                  obscureText: _obscureConfirmPassword,
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return 'Şifreler eşleşmiyor!';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              const SizedBox(height: 22),

                              // Giriş / Kayıt Butonu
                              Consumer<AuthProvider>(
                                builder: (ctx, auth, _) => SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: auth.isLoading ? null : _submit,
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            _authMode == AuthMode.Login
                                                ? 'Giriş Yap'
                                                : 'Kayıt Ol',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Mod Değiştirme Butonu
                              TextButton(
                                onPressed: _switchAuthMode,
                                child: Text(
                                  _authMode == AuthMode.Login
                                      ? 'Hesabınız yok mu? Kayıt Olun'
                                      : 'Zaten bir hesabınız var mı? Giriş Yapın',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.deepEspresso,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
