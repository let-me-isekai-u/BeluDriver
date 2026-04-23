import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'driver_login_screen.dart';
import '../terms_screen.dart';
import '../../providers/driver/register_provider.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

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
      _showSnack(context, "Đăng ký thành công!", color: theme.colorScheme.secondary);
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
      _showSnack(context, "Đăng ký thành công!", color: theme.colorScheme.secondary);
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
      appBar: AppBar(
        title: Text(
          "Đăng ký Tài khoản",
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildInfoCard(
                    theme: theme,
                    title: "Thông tin cá nhân",
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
                    title: "Bảo mật",
                    children: [
                      const _PasswordTextField(isConfirm: false),
                      const SizedBox(height: 16),
                      const _PasswordTextField(isConfirm: true),
                    ],
                  ),

                  const SizedBox(height: 20),
                  _TermsAndButton(onRegister: () => _handleRegister(context)),
                  const SizedBox(height: 25),

                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
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
                  const SizedBox(height: 20),
                ],
              ),
            ),

            if (loading)
              Container(
                color: theme.colorScheme.scrim.withOpacity(0.35),
                child: Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: theme.cardTheme.elevation ?? 0,
      shape: theme.cardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 18,
                color: theme.colorScheme.secondary,
              ),
            ),
            Divider(
              height: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.12),
            ),
            ...children,
          ],
        ),
      ),
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
      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
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

    final isObscure = isConfirm ? provider.obscureConfirmPassword : provider.obscurePassword;
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
      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
      decoration: _inputDecoration(theme, hint, Icons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
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
              side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.5)),
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
              side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.5)),
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
  return InputDecoration(
    labelText: hint,
    labelStyle: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.75),
    ),
    filled: true,
    fillColor: theme.colorScheme.surface.withOpacity(0.65),
    prefixIcon: Icon(icon, color: theme.colorScheme.secondary),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.colorScheme.secondary, width: 1.8),
    ),
  );
}