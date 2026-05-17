import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../providers/driver/login_provider.dart';
import '../../widgets/driver_ui.dart';
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.darkGreenBg, AppColors.primaryGreen],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: -80,
                  right: -30,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.08,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: size.height * 0.14,
                  left: -60,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DriverPill(
          label: "Nền tảng tài xế",
          icon: Icons.workspace_premium_rounded,
        ),
        const SizedBox(height: 18),
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.05).animate(
            CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
          ),
          child: Center(
            child: Container(
              width: 118,
              height: 118,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'lib/assets/icons/dong_duong_driver_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Tài xế Đông Dương",
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 30,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Đăng nhập để nhận chuyến, theo dõi doanh thu và vận hành công việc mỗi ngày trong cùng một hệ thống.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSubtle,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            DriverPill(label: "Nhận đơn nhanh", icon: Icons.flash_on_rounded),
            DriverPill(label: "KYC rõ ràng", icon: Icons.verified_user_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginFormCard(ThemeData theme, LoginProvider provider) {
    return DriverSectionCard(
      title: "Bắt đầu ca làm việc",
      subtitle: "Đăng nhập tài khoản để vào giao diện vận hành tài xế.",
      icon: Icons.lock_open_rounded,
      child: Column(
        children: [
          _buildTextField(
            controller: provider.phoneController,
            hint: "Số điện thoại",
            icon: Icons.phone_android_rounded,
            isPassword: false,
            obscurePassword: provider.obscurePassword,
            onTogglePassword: provider.togglePasswordVisibility,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: provider.passwordController,
            hint: "Mật khẩu",
            icon: Icons.lock_outline_rounded,
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
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: provider.isLoading ? null : () => _login(provider),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
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
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.secondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Tài khoản được duyệt KYC sẽ mở đầy đủ chức năng nhận đơn.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSubtle,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Chưa có tài khoản?",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.9,
                  ),
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
      decoration: driverInputDecoration(
        theme,
        label: hint,
        hint: hint,
        icon: icon,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                onPressed: onTogglePassword,
              )
            : null,
      ),
    );
  }
}
