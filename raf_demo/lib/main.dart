import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/auth_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/cart_provider.dart';

import 'services/api_service.dart'; // YENİ: ApiService'i import et
import 'services/socket_service.dart';

import 'screens/auth_screen.dart';
import 'screens/shops_screen.dart';
import 'screens/shop_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/merchant_dashboard_screen.dart'; // YENİ
import 'screens/add_product_from_catalog.dart'; // YENİ: AddProductFromCatalogScreen'i import et

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

  runApp(
    MultiProvider(
      providers: [
        // 1. AuthProvider, paylaşılan apiService'i alır.
        // (Not: AuthProvider sınıfınızın constructor'ını ApiService alacak şekilde güncellemelisiniz)
        ChangeNotifierProvider(
          create: (context) => AuthProvider(apiService, socketService),
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
      title: 'Market Teslimat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
            .copyWith(secondary: Colors.amber[700]),
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          // Eğer oturum açıksa ana sayfayı, değilse giriş ekranını göster.
          if (auth.isAuthenticated) {
            // Kullanıcı tipine göre yönlendirme yap
            return auth.userType == UserType.merchant
                ? const MerchantDashboardScreen()
                : const ShopsScreen();
          }
          // Oturum açık değilse, otomatik giriş yapmayı dene.
          return FutureBuilder(
            future: auth.tryAutoLogin(),
            builder: (ctx, authResultSnapshot) =>
                authResultSnapshot.connectionState == ConnectionState.waiting
                    ? const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : const AuthScreen(),
          );
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
      },
    );
  }
}
