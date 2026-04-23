import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver/login_provider.dart';
import '../forgot_password_screen.dart';
import 'driver_home.dart';
import 'driver_register_screen.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<DriverLoginScreen>
    with TickerProviderStateMixin {
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

  Future<void> _login(LoginProvider provider) async {
    final result = await provider.login();

    if (!mounted) return;

    if (result == null) {
      _showSnack(
        "Đăng nhập thành công!",
        color: Theme.of(context).colorScheme.secondary,
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
            (Route<dynamic> route) => false,
      );
    } else {
      _showSnack(result);
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

    return ChangeNotifierProvider(
      create: (_) => LoginProvider(),
      child: Consumer<LoginProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            body: Stack(
              children: [
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
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        _buildLogoSection(theme),
                        const SizedBox(height: 28),
                        _buildLoginFormCard(theme, provider),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
                'lib/assets/icons/dong_duong_driver_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Tài Xế Đông Dương",
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 28,
            letterSpacing: 2,
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFormCard(ThemeData theme, LoginProvider provider) {
    return Card(
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
              controller: provider.phoneController,
              hint: "Số điện thoại",
              icon: Icons.phone_android,
              isPassword: false,
              obscurePassword: provider.obscurePassword,
              onTogglePassword: provider.togglePasswordVisibility,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: provider.passwordController,
              hint: "Mật khẩu",
              icon: Icons.lock_outline,
              isPassword: true,
              obscurePassword: provider.obscurePassword,
              onTogglePassword: provider.togglePasswordVisibility,
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
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : () => _login(provider),
                child: provider.isLoading
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
    required bool obscurePassword,
    required VoidCallback onTogglePassword,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      cursorColor: theme.colorScheme.secondary,
      obscureText: isPassword ? obscurePassword : false,
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
            obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          onPressed: onTogglePassword,
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