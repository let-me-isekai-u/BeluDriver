import 'package:beludriver_app/features/carrier_vehicle/carrier_vehicle_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../providers/driver/login_provider.dart';
import '../../widgets/driver_ui.dart';
import '../forgot_password_screen.dart';
import 'driver_home.dart';
import 'driver_register_screen.dart';
import '../../ui/ui.dart';

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
        color: Brand.navy,
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
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
            body: Stack(
              children: [
                const ColoredBox(color: Brand.canvas, child: SizedBox.expand()),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: size.height * 0.42,
                  child: const ColoredBox(color: Brand.navy),
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
        Row(children: [
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.05).animate(
              CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              alignment: Alignment.center,
              child: const BrandMark(size: 28),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Đông Dương', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text('Nền tảng tài xế', style: TextStyle(color: Brand.b200, fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
        const SizedBox(height: 22),
        const Text(
          'Chào tài xế,\nsẵn sàng chạy chuyến?',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nhận đơn và theo dõi doanh thu mỗi ngày.',
          style: TextStyle(color: Brand.b100, fontSize: 14, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildLoginFormCard(ThemeData theme, LoginProvider provider) {
    return DriverSectionCard(
      title: "Bắt đầu ca làm việc",
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
                  color: Brand.navy,
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
                  color: Brand.navy.withValues(alpha: 0.16),
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
              color: Brand.b50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Brand.navy,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Cần duyệt KYC để nhận đơn.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Brand.inkMuted,
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
                    color: Brand.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Module Nhà xe: tài xế xe limousine/xe khách quét QR dán trên xe, không cần tài khoản.
          OutlinedButton.icon(
            onPressed: () => openCarrierVehicleMode(context),
            icon: Icon(Icons.qr_code_scanner, color: Brand.navy),
            label: Text(
              "Tài xế nhà xe: quét QR trên xe",
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: Brand.navy),
            ),
            style: OutlinedButton.styleFrom(side: BorderSide(color: Brand.navy)),
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
      cursorColor: Brand.navy,
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
