import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'driver/driver_login_screen.dart';
import '../ui/ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSendingCode = false;
  bool _isResetting = false;

  bool _showPass = false;
  bool _showConfirmPass = false;

  int _countdown = 0;
  Timer? _timer;
  String? _challengeId;
  String? _challengePhone;

  void _startCountdown() {
    _countdown = 60;
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
    final phone = _phoneController.text.trim();

    if (!RegExp(r'^(?:0|84|\+84)[35789][0-9]{8}$').hasMatch(phone)) {
      _showSnack("Vui lòng nhập số điện thoại di động hợp lệ");
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final res = await ApiService.sendForgotPasswordOtp(phone: phone);

      if (!mounted) return;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final id = body is Map ? body['challengeId'] : null;
      if (res.statusCode == 200 && id is String && id.isNotEmpty) {
        _challengeId = id;
        _challengePhone = phone;
        _codeController.clear();
        _showSnack(
          "Nếu số đã đăng ký, mã sẽ được gửi qua SMS. Mã có hiệu lực 3 phút.",
          color: Brand.navy,
        );
        _startCountdown();
      } else {
        _showSnack(
          body is Map && body['message'] is String
              ? body['message'] as String
              : "Gửi mã thất bại",
        );
      }
    } catch (e) {
      if (mounted) _showSnack("Không kết nối được máy chủ. Vui lòng thử lại.");
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final challengeId = _challengeId;
    if (challengeId == null || _challengePhone != phone) {
      _showSnack("Vui lòng yêu cầu mã xác minh cho số điện thoại này.");
      return;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(_codeController.text.trim())) {
      _showSnack("Mã SMS gồm 6 chữ số.");
      return;
    }
    setState(() => _isResetting = true);

    try {
      final res = await ApiService.resetPassword(
        phone: phone,
        challengeId: challengeId,
        otp: _codeController.text.trim(),
        newPassword: _passwordController.text.trim(),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        _showSnack("Đổi mật khẩu thành công!", color: Brand.navy);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
        );
      } else {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
        _showSnack(body["message"] ?? "Đổi mật khẩu thất bại");
      }
    } catch (e) {
      if (mounted) _showSnack("Không kết nối được máy chủ. Vui lòng thử lại.");
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _decor(
    ThemeData theme, {
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.75),
      ),
      filled: true,
      fillColor: theme.colorScheme.surface.withOpacity(0.65),
      prefixIcon: Icon(icon, color: Brand.navy),
      suffixIcon: suffixIcon,
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
        borderSide: BorderSide(color: Brand.navy, width: 1.8),
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
            color: Brand.navy, // GOLD
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

                // PHONE
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: _decor(
                    theme,
                    label: "Số điện thoại",
                    icon: Icons.phone,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return "Vui lòng nhập số điện thoại";
                    if (!RegExp(
                      r'^(?:0|84|\+84)[35789][0-9]{8}$',
                    ).hasMatch(v.trim()))
                      return "Số điện thoại không hợp lệ";
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
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: _decor(
                          theme,
                          label: "Mã xác thực",
                          icon: Icons.lock_clock_rounded,
                        ),
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
                        onPressed:
                            (_isSendingCode || _isResetting || _countdown > 0)
                            ? null
                            : _sendCode,
                        child: _isSendingCode
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_countdown > 0 ? "$_countdown s" : "Gửi mã"),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // NEW PASSWORD
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPass,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: _decor(
                    theme,
                    label: "Nhập lại mật khẩu",
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPass
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      onPressed: () =>
                          setState(() => _showConfirmPass = !_showConfirmPass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Nhập lại mật khẩu";
                    if (v != _passwordController.text.trim())
                      return "Mật khẩu không khớp";
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
                              color: Colors.white,
                            ),
                          )
                        : const Text("Đổi mật khẩu"),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Không còn dùng số đã đăng ký? Gọi 0964 986 902 để được hỗ trợ.",
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverLoginScreen(),
                      ),
                    );
                  },
                  child: Text(
                    "Quay về đăng nhập",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Brand.navy, // GOLD link
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
