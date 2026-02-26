import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'driver/driver_login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSendingCode = false;
  bool _isResetting = false;

  bool _showPass = false;
  bool _showConfirmPass = false;

  int _countdown = 0;
  Timer? _timer;

  void _startCountdown() {
    _countdown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _countdown--);
      }
    });
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

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains("@")) {
      _showSnack("Vui lòng nhập email hợp lệ");
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final res = await ApiService.sendForgotPasswordOtp(email: email);

      if (res.statusCode == 200) {
        _showSnack("Đã gửi mã xác thực!", color: Theme.of(context).colorScheme.secondary);
        _startCountdown();
      } else {
        _showSnack("Gửi mã thất bại");
      }
    } catch (e) {
      _showSnack("Lỗi kết nối: $e");
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isResetting = true);

    try {
      final res = await ApiService.resetPassword(
        email: _emailController.text.trim(),
        otp: _codeController.text.trim(),
        newPassword: _passwordController.text.trim(),
      );

      if (res.statusCode == 200) {
        _showSnack("Đổi mật khẩu thành công!", color: Theme.of(context).colorScheme.secondary);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
        );
      } else {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
        _showSnack(body["message"] ?? "Đổi mật khẩu thất bại");
      }
    } catch (e) {
      _showSnack("Lỗi kết nối: $e");
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _decor(ThemeData theme, {required String label, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.75),
      ),
      filled: true,
      fillColor: theme.colorScheme.surface.withOpacity(0.65),
      prefixIcon: Icon(icon, color: theme.colorScheme.secondary),
      suffixIcon: suffixIcon,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Quên mật khẩu",
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            color: theme.colorScheme.secondary, // GOLD
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // EMAIL
                TextFormField(
                  controller: _emailController,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                  decoration: _decor(theme, label: "Email", icon: Icons.email),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Vui lòng nhập email";
                    if (!v.contains("@")) return "Email không hợp lệ";
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // OTP + SEND
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                        decoration: _decor(theme, label: "Mã xác thực", icon: Icons.lock_clock_rounded),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Nhập mã xác thực";
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isSendingCode || _countdown > 0) ? null : _sendCode,
                        child: _isSendingCode
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                            : Text(_countdown > 0 ? "$_countdown s" : "Gửi mã"),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 18),

                // NEW PASSWORD
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPass,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                  decoration: _decor(
                    theme,
                    label: "Mật khẩu mới",
                    icon: Icons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPass ? Icons.visibility : Icons.visibility_off,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Nhập m��t khẩu mới";
                    if (v.length < 6) return "Mật khẩu tối thiểu 6 ký tự";
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // CONFIRM
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_showConfirmPass,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                  decoration: _decor(
                    theme,
                    label: "Nhập lại mật khẩu",
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPass ? Icons.visibility : Icons.visibility_off,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      onPressed: () => setState(() => _showConfirmPass = !_showConfirmPass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Nhập lại mật khẩu";
                    if (v != _passwordController.text.trim()) return "Mật khẩu không khớp";
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                // RESET BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isResetting ? null : _resetPassword,
                    child: _isResetting
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                        : const Text("Đổi mật khẩu"),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
                    );
                  },
                  child: Text(
                    "Quay về đăng nhập",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary, // GOLD link
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}