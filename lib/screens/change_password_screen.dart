import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController oldPassController = TextEditingController();
  final TextEditingController newPassController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool obscureOld = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  void _toast(String msg, {Color? color}) {
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
        backgroundColor: color ?? theme.colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Đổi mật khẩu",
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            color: theme.colorScheme.secondary, // GOLD title
          ),
        ),
        // không set backgroundColor để ăn appBarTheme
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(
                  Icons.lock_reset,
                  size: 85,
                  color: theme.colorScheme.secondary, // GOLD icon
                ),
              ),
              const SizedBox(height: 30),

              _buildField(
                theme: theme,
                controller: oldPassController,
                hint: "Mật khẩu cũ",
                obscureText: obscureOld,
                onToggle: () => setState(() => obscureOld = !obscureOld),
              ),
              const SizedBox(height: 16),

              _buildField(
                theme: theme,
                controller: newPassController,
                hint: "Mật khẩu mới",
                obscureText: obscureNew,
                onToggle: () => setState(() => obscureNew = !obscureNew),
              ),
              const SizedBox(height: 16),

              _buildField(
                theme: theme,
                controller: confirmController,
                hint: "Xác nhận mật khẩu",
                obscureText: obscureConfirm,
                onToggle: () => setState(() => obscureConfirm = !obscureConfirm),
              ),

              const Spacer(),

              // ăn ElevatedButtonTheme (brightYellow)
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleChangePassword,
                  child: const Text("Đổi mật khẩu"),
                ),
              ),
              const SizedBox(height: 12),

              // ăn OutlinedButtonTheme (viền trắng)
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Huỷ"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Logic đổi mật khẩu =====
  Future<void> _handleChangePassword() async {
    final oldPass = oldPassController.text.trim();
    final newPass = newPassController.text.trim();
    final confirm = confirmController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      return _toast("Vui lòng nhập đầy đủ thông tin", color: Theme.of(context).colorScheme.error);
    }

    if (oldPass == newPass) {
      return _toast("Mật khẩu mới không được trùng mật khẩu cũ", color: Theme.of(context).colorScheme.error);
    }

    final strongPassRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );

    if (!strongPassRegex.hasMatch(newPass)) {
      return _toast(
        "Mật khẩu quá yếu (cần chữ hoa, chữ thường, số và ký tự đặc biệt, tối thiểu 8 ký tự)",
        color: Theme.of(context).colorScheme.error,
      );
    }

    if (newPass != confirm) {
      return _toast("Mật khẩu xác nhận không khớp", color: Theme.of(context).colorScheme.error);
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    if (token == null) {
      _toast("Phiên đăng nhập hết hạn!", color: Theme.of(context).colorScheme.error);
      return;
    }

    final res = await ApiService.changePassword(
      accessToken: token,
      oldPassword: oldPass,
      newPassword: newPass,
    );

    if (res.statusCode == 200) {
      _toast("Đổi mật khẩu thành công!", color: Theme.of(context).colorScheme.secondary);
      if (mounted) Navigator.pop(context);
    } else {
      _toast("Đổi mật khẩu thất bại\n${res.body}", color: Theme.of(context).colorScheme.error);
    }
  }

  Widget _buildField({
    required ThemeData theme,
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.75),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.65),
        prefixIcon: Icon(Icons.key, color: theme.colorScheme.secondary),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
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
            color: theme.colorScheme.secondary, // GOLD focus
            width: 1.8,
          ),
        ),
      ),
    );
  }
}