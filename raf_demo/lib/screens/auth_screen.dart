import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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

  // --- YENİ: Dükkan Sahibi için Controller'lar ---
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  String? _selectedCity; // Dükkanın şehri için

  // Mevcut auth modunu tutar
  AuthMode _authMode = AuthMode.Login;

  // "Müşteriyim" / "Satıcıyım" seçimi için
  UserType _userType = UserType.customer;

  // Örnek şehir listesi. Normalde bu da API'den gelmeli.
  // Kayıt için "Tüm Şehirler" seçeneğini kaldırıyoruz.
  final List<String> _cities = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Antalya'
  ];

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
              backgroundColor: Colors.green,
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
              backgroundColor: Colors.green,
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
    final deviceSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: deviceSize.width * 0.85,
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Logo veya başlık
                  Icon(Icons.shopping_cart_checkout,
                      size: 80, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 20),
                  Text(
                    _authMode == AuthMode.Login
                        ? 'Hoş Geldiniz!'
                        : 'Hesap Oluşturun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Müşteri / Satıcı seçimi
                  // Sadece giriş modunda Müşteri/Satıcı seçimi gösterilir.
                  // Kayıt işlemi sadece müşteriler için olduğundan bu bölüm gizlenir.
                  if (_authMode == AuthMode.Login) ...[
                    SegmentedButton<UserType>(
                      segments: const <ButtonSegment<UserType>>[
                        ButtonSegment<UserType>(
                            value: UserType.customer,
                            label: Text('Müşteriyim'),
                            icon: Icon(Icons.person)),
                        ButtonSegment<UserType>(
                            value: UserType.merchant,
                            label: Text('Satıcıyım'),
                            icon: Icon(Icons.store)),
                      ],
                      selected: <UserType>{_userType},
                      onSelectionChanged: (Set<UserType> newSelection) {
                        setState(() {
                          _userType = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // --- DİNAMİK FORM ALANLARI ---

                  // Müşteri Giriş/Kayıt için Kullanıcı Adı/E-posta
                  if (_userType == UserType.customer)
                    TextFormField(
                      controller: _identifierController,
                      decoration: InputDecoration(
                        labelText: _authMode == AuthMode.Login
                            ? 'E-posta veya Kullanıcı Adı'
                            : 'Kullanıcı Adı',
                        prefixIcon: const Icon(Icons.account_circle),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                      _authMode == AuthMode.Register)
                    TextFormField(
                      controller: _shopNameController,
                      decoration: InputDecoration(
                        labelText: 'Market Adı',
                        prefixIcon: const Icon(Icons.storefront),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen market adını girin.';
                        }
                        return null;
                      },
                    ),

                  const SizedBox(height: 12),

                  // Dükkan Kayıt için Sahip Adı
                  if (_userType == UserType.merchant &&
                      _authMode == AuthMode.Register) ...[
                    TextFormField(
                      controller: _ownerNameController,
                      decoration: InputDecoration(
                        labelText: 'Dükkan Sahibi (Ad Soyad)',
                        prefixIcon: const Icon(Icons.person_pin),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen adınızı ve soyadınızı girin.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 12),

                  // Sadece Kayıt modunda gösterilecek alanlar
                  // Müşteri Kayıt için E-posta
                  if (_userType == UserType.customer &&
                      _authMode == AuthMode.Register) ...[
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-posta Adresi',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Lütfen geçerli bir e-posta adresi girin.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Müşteri Kayıt için Şehir Seçimi
                  if (_userType == UserType.customer &&
                      _authMode == AuthMode.Register) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      decoration: InputDecoration(
                        labelText: 'Şehir',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                    const SizedBox(height: 12),
                  ],

                  // Telefon Numarası (Kayıt) veya Tanımlayıcı (Dükkan Giriş)
                  if ((_userType == UserType.customer &&
                          _authMode == AuthMode.Register) ||
                      _userType == UserType.merchant)
                    TextFormField(
                      controller:
                          _phoneController, // Bu controller artık çok amaçlı kullanılıyor
                      decoration: InputDecoration(
                        labelText: _userType == UserType.merchant &&
                                _authMode == AuthMode.Login
                            ? 'Market Adı veya Telefon No'
                            : 'Telefon Numarası',
                        prefixIcon: Icon(_userType == UserType.merchant &&
                                _authMode == AuthMode.Login
                            ? Icons.store
                            : Icons.phone),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: _authMode == AuthMode.Register
                          ? TextInputType.phone
                          : TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bu alanı doldurun.';
                        }
                        // Kayıt modunda her zaman telefon numarası girildiği için uzunluk kontrolü yap
                        if (_authMode == AuthMode.Register &&
                            value.length < 10) {
                          return 'Lütfen geçerli bir telefon numarası girin.';
                        }
                        return null;
                      },
                    ),

                  const SizedBox(height: 12),

                  // Dükkan Kayıt için Şehir Seçimi
                  if (_userType == UserType.merchant &&
                      _authMode == AuthMode.Register) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      decoration: InputDecoration(
                        labelText: 'Şehir',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                    const SizedBox(height: 12),
                  ],

                  // Şifre alanı
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        return 'Şifre en az 6 karakter olmalıdır.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Şifre Tekrar alanı (sadece kayıt modunda)
                  if (_authMode == AuthMode.Register) ...[
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Şifreyi Onayla',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Şifreler eşleşmiyor!';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Giriş Butonu
                  Consumer<AuthProvider>(
                    builder: (ctx, auth, _) => auth.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submit,
                            child: Text(_authMode == AuthMode.Login
                                ? 'Giriş Yap'
                                : 'Kayıt Ol'),
                          ),
                  ),
                  TextButton(
                    onPressed: _switchAuthMode,
                    child: Text(_authMode == AuthMode.Login
                        ? 'Hesabınız yok mu? Kayıt Olun'
                        : 'Zaten bir hesabınız var mı? Giriş Yapın'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
