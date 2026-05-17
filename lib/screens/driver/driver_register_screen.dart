import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import 'driver_login_screen.dart';
import '../terms_screen.dart';
import '../../providers/driver/register_provider.dart';
import '../../widgets/driver_ui.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterProvider(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  void _showSnack(BuildContext context, String msg, {Color? color}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
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

  Future<void> _handleRegister(BuildContext context) async {
    final provider = context.read<RegisterProvider>();
    final theme = Theme.of(context);

    final success = await provider.register(
      onSnack: (msg, {color}) => _showSnack(context, msg, color: color),
    );

    if (success && context.mounted) {
      _showSnack(
        context,
        "Đăng ký thành công!",
        color: theme.colorScheme.secondary,
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = context.select<RegisterProvider, bool>((p) => p.loading);

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
            top: -70,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.07),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.06,
                              ),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Đăng ký tài khoản",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Tạo hồ sơ tài xế để hoàn tất đăng ký, sau đó tiếp tục KYC và mở chức năng nhận đơn.",
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
                          DriverPill(
                            label: "3 nhóm thông tin",
                            icon: Icons.fact_check_rounded,
                          ),
                          DriverPill(
                            label: "Giữ nguyên theme cũ",
                            icon: Icons.palette_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildInfoCard(
                        theme: theme,
                        title: "Thông tin cá nhân",
                        subtitle: "Tên hiển thị, email và biển số xe.",
                        icon: Icons.badge_outlined,
                        children: [
                          _ProviderTextField(
                            getController: (p) => p.fullNameController,
                            hint: "Họ và tên",
                            icon: Icons.badge,
                          ),
                          const SizedBox(height: 16),
                          _ProviderTextField(
                            getController: (p) => p.emailController,
                            hint: "Email",
                            icon: Icons.email,
                          ),
                          const SizedBox(height: 16),
                          _ProviderTextField(
                            getController: (p) => p.licenseNumberController,
                            hint: "Biển số xe",
                            icon: Icons.directions_car,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        theme: theme,
                        title: "Thông tin liên hệ",
                        subtitle:
                            "Số điện thoại dùng để đăng nhập và nhận liên hệ.",
                        icon: Icons.call_outlined,
                        children: [
                          _ProviderTextField(
                            getController: (p) => p.phoneController,
                            hint: "Số điện thoại",
                            icon: Icons.phone,
                            isPhone: true,
                          ),
                          const SizedBox(height: 16),
                          _ProviderTextField(
                            getController: (p) => p.confirmPhoneController,
                            hint: "Nhập lại số điện thoại",
                            icon: Icons.phone_android,
                            isPhone: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        theme: theme,
                        title: "Bảo mật tài khoản",
                        subtitle:
                            "Đặt mật khẩu mạnh để bảo vệ tài khoản tài xế.",
                        icon: Icons.lock_outline_rounded,
                        children: [
                          const _PasswordTextField(isConfirm: false),
                          const SizedBox(height: 16),
                          const _PasswordTextField(isConfirm: true),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DriverSectionCard(
                        title: "Xác nhận điều kiện",
                        subtitle:
                            "Hoàn tất các xác nhận bắt buộc trước khi gửi hồ sơ.",
                        icon: Icons.verified_user_outlined,
                        child: _TermsAndButton(
                          onRegister: () => _handleRegister(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DriverLoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Bạn đã có tài khoản? Quay về đăng nhập",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                if (loading)
                  Container(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.35),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required ThemeData theme,
    required String title,
    String? subtitle,
    IconData? icon,
    required List<Widget> children,
  }) {
    return DriverSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: Column(children: children),
    );
  }
}

class _ProviderTextField extends StatelessWidget {
  final TextEditingController Function(RegisterProvider) getController;
  final String hint;
  final IconData icon;
  final bool isPhone;

  const _ProviderTextField({
    required this.getController,
    required this.hint,
    required this.icon,
    this.isPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = getController(context.read<RegisterProvider>());

    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: _inputDecoration(theme, hint, icon),
    );
  }
}

class _PasswordTextField extends StatelessWidget {
  final bool isConfirm;

  const _PasswordTextField({required this.isConfirm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<RegisterProvider>();

    final isObscure = isConfirm
        ? provider.obscureConfirmPassword
        : provider.obscurePassword;
    final toggle = isConfirm
        ? provider.toggleObscureConfirmPassword
        : provider.toggleObscurePassword;
    final controller = isConfirm
        ? provider.confirmPasswordController
        : provider.passwordController;
    final hint = isConfirm ? "Nhập lại mật khẩu" : "Mật khẩu";

    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: _inputDecoration(theme, hint, Icons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}

class _TermsAndButton extends StatelessWidget {
  final VoidCallback onRegister;

  const _TermsAndButton({required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<RegisterProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              value: provider.agreeTerms,
              activeColor: theme.colorScheme.secondary,
              checkColor: theme.colorScheme.onSecondary,
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onChanged: (v) => provider.setAgreeTerms(v ?? false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                ),
                child: Text(
                  "Tôi đồng ý với Chính sách & Điều khoản sử dụng",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: provider.agreeCamera,
              activeColor: theme.colorScheme.secondary,
              checkColor: theme.colorScheme.onSecondary,
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onChanged: (v) => provider.setAgreeCamera(v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  "Tôi cam kết xe có gắn camera hành trình và đang hoạt động bình thường",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: provider.canSubmit ? onRegister : null,
            child: provider.loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : const Text("Đăng ký"),
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(ThemeData theme, String hint, IconData icon) {
  return driverInputDecoration(theme, label: hint, hint: hint, icon: icon);
}
