import 'package:flutter/material.dart';

class AppColors {
  // Màu chính: Xanh ngọc lục bảo (Emerald) - Tạo sự khác biệt với màu xanh dương của khách
  static const Color primary = Color(0xFF4CD7A7);
  static const Color primaryDark = Color(0xFF2BB38A);

  // Màu bổ trợ: Cam nhẹ hoặc Vàng (Dùng cho các cảnh báo hoặc nút phụ của tài xế)
  static const Color accent = Color(0xFFFFA726);

  // Nền: Xám cực nhẹ để các Card trắng nổi bật lên
  static const Color background = Color(0xFFF0F4F3);

  static const Color textDark = Color(0xFF2F2F2F);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF757575);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto', // Hoặc font bạn đang dùng

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        tertiary: AppColors.accent,
        surface: Colors.white,
        background: AppColors.background,
        onPrimary: AppColors.textLight,
        onSurface: AppColors.textDark,
      ),

      scaffoldBackgroundColor: AppColors.background,

      /// AppBar: Đồng bộ với phong cách hiện đại, phẳng hoặc đổ bóng nhẹ
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 0, // Để 0 nếu muốn dùng Stack như màn Login/Register
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textLight),
        titleTextStyle: TextStyle(
          color: AppColors.textLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      /// Card: Tự động bo góc cho toàn bộ app
      /// CardThemeData thay vì CardTheme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),

      /// Elevated Button: Nút bấm bo tròn hiện đại
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          disabledBackgroundColor: Colors.grey.shade400,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          elevation: 2,
        ),
      ),

      /// TextField: Đồng bộ với UI "Grey Fill" chúng ta đã làm
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),

      /// Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: AppColors.textDark, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textDark, fontSize: 14),
      ),
    );
  }
}