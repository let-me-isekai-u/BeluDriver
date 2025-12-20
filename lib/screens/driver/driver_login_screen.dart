import 'package:flutter/material.dart';
import 'driver_home.dart';
import 'driver_register_screen.dart';
import '../forgot_password_screen.dart'; // Đảm bảo đường dẫn này đúng với cấu trúc mới
import 'dart:convert';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<DriverLoginScreen> with TickerProviderStateMixin {
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

  void _showSnack(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final deviceToken = ""; // Tạm thời để trống theo code cũ của bạn

    try {
      final res = await ApiService.driverLogin(
        phone: phone,
        password: password,
        deviceToken: deviceToken,
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

        _showSnack("Đăng nhập thành công!", color: const Color(0xFF4CD7A7));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _goToForgotPassword() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. NỀN XANH NGỌC CỦA DRIVER
          Container(
            height: size.height * 0.4,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(60),
                bottomRight: Radius.circular(60),
              ),
            ),
          ),

          // 2. NỘI DUNG CHÍNH
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildLogoSection(),
                  const SizedBox(height: 30),
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

  Widget _buildLogoSection() {
    return Column(
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.05).animate(
            CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
          ),
          child: Container(
            width: 120, // Kích thước nhỏ hơn 1 chút
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), // Bo góc nhiều hơn
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4), // Bóng đậm hơn
                  blurRadius: 20,
                  spreadRadius: 3,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'lib/assets/icons/BeluCar_logo.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "BeluDriver",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFormCard(ThemeData theme) {
    return Card(
      elevation: 10,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Text(
              "Chào Tài Xế!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Đăng nhập để bắt đầu nhận chuyến",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildTextField(phoneController, "Số điện thoại", Icons.phone_android, false),
            const SizedBox(height: 20),
            _buildTextField(passwordController, "Mật khẩu", Icons.lock_outline, true),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _goToForgotPassword,
                child: Text("Quên mật khẩu?", style: TextStyle(color: theme.colorScheme.primary)),
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 5,
              ),
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("BẮT ĐẦU LÀM VIỆC", style: TextStyle(fontSize: 16, letterSpacing: 1.1)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Chưa có tài khoản?"),
                TextButton(
                  onPressed: _goToRegister,
                  child: Text(
                    "Đăng ký ngay",
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, bool isPassword) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isPassword ? TextInputType.text : TextInputType.phone,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
      ),
    );
  }
}