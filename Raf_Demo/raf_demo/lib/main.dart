import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/auth_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/cart_provider.dart';

import 'services/api_service.dart';
import 'services/socket_service.dart';

import 'utils/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/shops_screen.dart';
import 'screens/shop_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/merchant_dashboard_screen.dart';
import 'screens/add_product_from_catalog.dart';
import 'screens/create_package_screen.dart';
import 'screens/package_detail_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  final apiService = ApiService();
  final socketService = SocketService();
  socketService.connect();

  final authProvider = AuthProvider(apiService, socketService);
  await authProvider.tryAutoLogin();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: authProvider,
        ),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (context) => CartProvider(apiService, socketService),
          update: (context, auth, previousCartProvider) {
            apiService.setAuthToken(auth.token);
            return previousCartProvider!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ShopProvider>(
          create: (context) => ShopProvider(apiService, socketService),
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
          if (auth.isAuthenticated) {
            return auth.userType == UserType.merchant
                ? const MerchantDashboardScreen()
                : const ShopsScreen();
          }
          return const AuthScreen();
        },
      ),
      routes: {
        AuthScreen.routeName: (ctx) => const AuthScreen(),
        ShopsScreen.routeName: (ctx) => const ShopsScreen(),
        ShopDetailScreen.routeName: (ctx) => const ShopDetailScreen(),
        CartScreen.routeName: (ctx) => const CartScreen(),
        MerchantDashboardScreen.routeName: (ctx) =>
            const MerchantDashboardScreen(),
        AddProductFromCatalogScreen.routeName: (ctx) =>
            const AddProductFromCatalogScreen(),
        CreatePackageScreen.routeName: (ctx) =>
            const CreatePackageScreen(),
        PackageDetailScreen.routeName: (ctx) =>
            const PackageDetailScreen(),
        ProfileScreen.routeName: (ctx) =>
            const ProfileScreen(),
      },
    );
  }
}
