import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/auth_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/cart_provider.dart';

import 'services/api_service.dart'; // YENİ: ApiService'i import et
import 'services/socket_service.dart';

import 'utils/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/shops_screen.dart';
import 'screens/shop_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/merchant_dashboard_screen.dart'; // YENİ
import 'screens/add_product_from_catalog.dart'; // YENİ: AddProductFromCatalogScreen'i import et
import 'screens/create_package_screen.dart'; // YENİ: CreatePackageScreen'i import et
import 'screens/package_detail_screen.dart'; // YENİ: PackageDetailScreen'i import et
import 'screens/profile_screen.dart'; // YENİ: ProfileScreen'i import et

void main() async {
  // Flutter binding'in başlatıldığından emin ol.
  WidgetsFlutterBinding.ensureInitialized();
  // Tarih formatlama için Türkçe yerel ayar verilerini yükle.
  // Bu, 'intl' paketinin düzgün çalışması için gereklidir.
  await initializeDateFormatting('tr_TR', null);

  // Servisleri burada başlatıp Provider'lara enjekte etmek en temiz yöntemdir.
  final apiService =
      ApiService(); // Tüm provider'ların kullanacağı tek bir ApiService örneği
  final socketService = SocketService();
  socketService.connect(); // Uygulama başlarken socket bağlantısını kur.

  final authProvider = AuthProvider(apiService, socketService);
  // Uygulama başlarken hafızadaki oturum verisini (varsa) otomatik yükle
  await authProvider.tryAutoLogin();

  runApp(
    MultiProvider(
      providers: [
        // 1. Önceden başlatılmış ve oturum durumu yüklenmiş AuthProvider
        ChangeNotifierProvider.value(
          value: authProvider,
        ),

        // 2. Diğer provider'ları AuthProvider'a bağlamak için ChangeNotifierProxyProvider kullanılır.
        // Bu, login/logout gibi durumlarda diğer provider'ların da güncellenmesini sağlar.
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          // CartProvider'ın constructor'ı da ApiService alacak şekilde güncellenmeli.
          create: (context) => CartProvider(apiService, socketService),
          update: (context, auth, previousCartProvider) {
            // AuthProvider her güncellendiğinde (login, logout, vb.) bu blok çalışır.
            // ApiService'teki token'ı, AuthProvider'daki güncel token ile senkronize eder.
            // Kullanıcı çıkış yaptığında auth.token null olacağı için token temizlenmiş olur.
            apiService.setAuthToken(auth.token);
            // previousCartProvider'ı geri döndürmek yeterli, çünkü hepsi aynı apiService'i paylaşıyor.
            return previousCartProvider!;
          },
        ),

        ChangeNotifierProxyProvider<AuthProvider, ShopProvider>(
          // ShopProvider'ın constructor'ı (apiService, socketService) alıyor.
          create: (context) => ShopProvider(apiService, socketService),
          // `update` içinde tekrar token eklemeye gerek yok, çünkü bu işlem
          // yukarıdaki CartProvider'ın `update` bloğunda zaten yapıldı.
          // Bir proxy'de yapmak yeterlidir.
          update: (_, auth, previousShopProvider) => previousShopProvider!,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          // Eğer oturum açıksa ana sayfayı (satıcı veya müşteri), değilse giriş ekranını göster.
          if (auth.isAuthenticated) {
            return auth.userType == UserType.merchant
                ? const MerchantDashboardScreen()
                : const ShopsScreen();
          }
          return const AuthScreen();
        },
      ),
      // Rotaları tanımla (sayfa geçişleri için)
      routes: {
        AuthScreen.routeName: (ctx) => const AuthScreen(),
        ShopsScreen.routeName: (ctx) => const ShopsScreen(),
        ShopDetailScreen.routeName: (ctx) => const ShopDetailScreen(),
        CartScreen.routeName: (ctx) => const CartScreen(),
        OrdersScreen.routeName: (ctx) => const OrdersScreen(),
        MerchantDashboardScreen.routeName: (ctx) =>
            const MerchantDashboardScreen(), // YENİ
        AddProductFromCatalogScreen.routeName: (ctx) =>
            const AddProductFromCatalogScreen(), // YENİ: Rota tanımı eklendi
        CreatePackageScreen.routeName: (ctx) =>
            const CreatePackageScreen(), // YENİ: Paket Oluşturucu Rotası
        PackageDetailScreen.routeName: (ctx) =>
            const PackageDetailScreen(), // YENİ: Paket Detay Rotası
        ProfileScreen.routeName: (ctx) =>
            const ProfileScreen(), // YENİ: Profilim Rotası
      },
    );
  }
}
