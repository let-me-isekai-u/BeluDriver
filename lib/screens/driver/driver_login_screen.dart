import 'package:flutter/material.dart';
import 'driver_home.dart';
import 'driver_register_screen.dart';
import '../forgot_password_screen.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/firebase_notification_service.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<DriverLoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {Color? color}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: color ?? theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // GIỮ NGUYÊN LOGIC LOGIN API
  Future<void> _login() async {
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showSnack("Vui lòng nhập đầy đủ thông tin");
      return;
    }

    setState(() => _isLoading = true);
    String? deviceToken = await FirebaseNotificationService.getDeviceToken();
    final String tokenToSend = deviceToken ?? "";

    try {
      final res = await ApiService.driverLogin(
        phone: phone,
        password: password,
        deviceToken: tokenToSend,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final accessToken = data["accessToken"] ?? "";
        final refreshToken = data["refreshToken"] ?? "";
        final fullName = data["fullName"] ?? "";

        if (accessToken.isEmpty) {
          _showSnack("Server không trả về accessToken");
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("accessToken", accessToken);
        await prefs.setString("refreshToken", refreshToken);
        await prefs.setString("fullName", fullName);

        // dùng secondary (gold) cho success cho đúng palette
        _showSnack("Đăng nhập thành công!", color: Theme.of(context).colorScheme.secondary);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
              (Route<dynamic> route) => false,
        );
      } else {
        final err = jsonDecode(res.body);
        _showSnack(err["message"] ?? "Sai tài khoản hoặc mật khẩu");
      }
    } catch (e) {
      _showSnack("Lỗi kết nối: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1) Background top banner theo theme (dark green)
          Container(
            height: size.height * 0.38,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(60),
                bottomRight: Radius.circular(60),
              ),
            ),
          ),

          // 2) Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildLogoSection(theme),
                  const SizedBox(height: 28),
                  _buildLoginFormCard(theme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection(ThemeData theme) {
    return Column(
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.05).animate(
            CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
          ),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // logo nền sáng để nổi bật, nhưng dùng scheme cho hợp theme
              color: theme.colorScheme.onPrimary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 3,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'lib/assets/icons/BeluDriver_launcher.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "BeluDriver",
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 28,
            letterSpacing: 2,
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFormCard(ThemeData theme) {
    return Card(
      // dùng cardTheme (mà bạn đã set màu + border)
      elevation: theme.cardTheme.elevation ?? 0,
      shape: theme.cardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Text(
              "Chào Tài Xế!",
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Đăng nhập để bắt đầu nhận chuyến",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),

            _buildTextField(
              controller: phoneController,
              hint: "Số điện thoại",
              icon: Icons.phone_android,
              isPassword: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: passwordController,
              hint: "Mật khẩu",
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _goToForgotPassword,
                child: Text(
                  "Quên mật khẩu?",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Button dùng ElevatedButtonTheme (brightYellow)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: theme.colorScheme.primary,
                  ),
                )
                    : const Text(
                  "BẮT ĐẦU LÀM VIỆC",
                  style: TextStyle(letterSpacing: 1.1),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Chưa có tài khoản?",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
                  ),
                ),
                TextButton(
                  onPressed: _goToRegister,
                  child: Text(
                    "Đăng ký ngay",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPassword,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      cursorColor: theme.colorScheme.secondary,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isPassword ? TextInputType.text : TextInputType.phone,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        labelText: hint,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.75),
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.60),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.65),
        prefixIcon: Icon(icon, color: theme.colorScheme.secondary),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.onSurface.withOpacity(0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.secondary,
            width: 1.8,
          ),
        ),
      ),
    );
  }
}