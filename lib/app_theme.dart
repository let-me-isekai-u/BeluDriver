import 'package:flutter/material.dart';

/// Lớp định nghĩa bảng màu dựa trên thiết kế Belucar
class AppColors {
  // Màu xanh lục đậm chủ đạo (Deep Forest Green)
  static const Color primaryGreen = Color(0xFF0F3D2E);
  static const Color darkGreenBg = Color(0xFF0A2E22);

  // Màu vàng cát/vàng đồng (Sand Gold)
  static const Color accentGold = Color(0xFFE5C17B);
  static const Color brightYellow = Color(0xFFFFD166);

  // Màu phụ trợ
  static const Color surfaceGreen = Color(0xFF164A39);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSubtle = Color(0xFFB0C4BE);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGreen,
        secondary: AppColors.accentGold,
        surface: AppColors.surfaceGreen,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
      ),

      scaffoldBackgroundColor: AppColors.darkGreenBg,

      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      /// Elevated Button: Màu vàng rực (Nút Đặt xe ngay)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brightYellow,
          foregroundColor: const Color(0xFF0F3D2E),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      /// Outlined Button: Viền trắng (Nút Tra cứu)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),

      /// Card Theme: Cho các box nội dung
      cardTheme: CardThemeData(
        color: AppColors.surfaceGreen.withValues(alpha: 0.4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceGreen.withValues(alpha: 0.65),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColors.textSubtle),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceGreen,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryGreen,
        selectedItemColor: AppColors.accentGold,
        unselectedItemColor: Colors.white.withValues(alpha: 0.5),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        type: BottomNavigationBarType.fixed,
      ),

      textTheme: const TextTheme(
        // Tiêu đề cho màn hình chính (Login, Welcome...)
        headlineLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 28,
          height: 1.2,
        ),
        // Tiêu đề lớn nhất với màu vàng (cho các section nội dung)
        displayMedium: TextStyle(
          color: AppColors.accentGold,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          color: AppColors.accentGold,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textSubtle, fontSize: 14),
      ),
    );
  }
}
