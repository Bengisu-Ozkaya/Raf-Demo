import 'package:flutter/material.dart';

/// Raf Uygulaması Renk Paleti ve Tasarım Sistemi
class AppColors {
  // Kullanıcı tarafından iletilen ana 4 renk
  static const Color cream =
      Color(0xFFF7E6CA); // #F7E6CA - Sıcak krem zemin / arka plan
  static const Color sand =
      Color(0xFFE8D59E); // #E8D59E - Sıcak buğday / kum vurgusu
  static const Color dustyRose =
      Color(0xFFD9BBB0); // #D9BBB0 - Gül kurusu / pudra terracotta
  static const Color taupe =
      Color(0xFFAD9C8E); // #AD9C8E - Sıcak toprak / kaşmir taupe

  // Tipografi ve Kontrast (WCAG AAA uyumlu derin tonlar)
  static const Color deepEspresso =
      Color(0xFF2E241E); // Okunabilir ana başlık & metinler
  static const Color mochaText =
      Color(0xFF635349); // İkincil metinler ve açıklamalar
  static const Color lightText =
      Color(0xFF8C7B71); // Yardımcı ipucu & placeholder metinleri

  // Yüzey ve Kart Renkleri
  static const Color background =
      Color(0xFFFAF6F0); // Çok hafif sıcak krem zemin
  static const Color surface = Colors.white; // Temiz beyaz kart zemini
  static const Color surfaceSubtle =
      Color(0xFFF5ECE1); // Hafif renkli kart ve konteyner zemini
  static const Color border = Color(0xFFE4D6C8); // Yumuşak doğal kenarlık

  // Semantik Durum Renkleri (Earthy tonlarla uyumlu)
  static const Color success =
      Color(0xFF4E7D5B); // Doğal adaçayı yeşili (Stok var, onay)
  static const Color warning = Color(0xFFD98A3C); // Sıcak hardal/amber
  static const Color error =
      Color(0xFFC85A54); // Terracotta kırmızı (Hata, tükendi)

  // Gradyanlar
  static const LinearGradient warmHeaderGradient = LinearGradient(
    colors: [taupe, Color(0xFF968577)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardAccentGradient = LinearGradient(
    colors: [cream, sand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.taupe,
      onPrimary: Colors.white,
      primaryContainer: AppColors.cream,
      onPrimaryContainer: AppColors.deepEspresso,
      secondary: AppColors.dustyRose,
      onSecondary: AppColors.deepEspresso,
      secondaryContainer: AppColors.sand,
      onSecondaryContainer: AppColors.deepEspresso,
      surface: AppColors.surface,
      onSurface: AppColors.deepEspresso,
      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.taupe,

      // Tipografi & Yazı Teması
      fontFamily: null, // Cihazın temiz sistem fontunu kullanır
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.deepEspresso,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.deepEspresso,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.deepEspresso,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: AppColors.deepEspresso,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        bodyLarge: TextStyle(
          color: AppColors.deepEspresso,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: AppColors.mochaText,
          fontSize: 13.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.lightText,
          fontSize: 12,
        ),
      ),

      // AppBar Tasarımı
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.taupe,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Kart Tasarımı
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1.5,
        shadowColor: AppColors.taupe.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Giriş Kutuları (TextField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.lightText, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.mochaText, fontSize: 14),
        prefixIconColor: AppColors.taupe,
        suffixIconColor: AppColors.taupe,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.taupe, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),

      // Birincil Buton (ElevatedButton)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.taupe,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: AppColors.taupe.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // İkincil Buton (OutlinedButton)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepEspresso,
          side: const BorderSide(color: AppColors.dustyRose, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.taupe,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // Segmented Button
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.taupe;
            }
            return AppColors.surfaceSubtle;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return AppColors.deepEspresso;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.border),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),

      // Chip Tasarımı
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSubtle,
        selectedColor: AppColors.sand,
        labelStyle:
            const TextStyle(color: AppColors.deepEspresso, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.taupe,
        foregroundColor: Colors.white,
        elevation: 3,
      ),

      // SnackBar Tasarımı
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.deepEspresso,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
