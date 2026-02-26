import 'package:flutter/material.dart';
import 'driver_login_screen.dart';
import '../terms_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _confirmPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  XFile? _avatar;

  bool _agreeTerms = false;
  bool _loading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _showSnack(String msg, {Color? color}) {
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

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _avatar = picked);
      }
    } catch (e) {
      _showSnack("Không thể chọn ảnh: $e");
    }
  }

  bool _validateForm() {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    final phoneRegex = RegExp(r'^[0-9]{9,11}$');
    final strongPassRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );

    if (_fullNameController.text.trim().isEmpty) {
      _showSnack("Họ tên không được để trống");
      return false;
    }

    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showSnack("Email không hợp lệ");
      return false;
    }

    if (!phoneRegex.hasMatch(_phoneController.text.trim())) {
      _showSnack("Số điện thoại không hợp lệ");
      return false;
    }

    if (_phoneController.text.trim() != _confirmPhoneController.text.trim()) {
      _showSnack("Số điện thoại nhập lại không trùng");
      return false;
    }

    if (!strongPassRegex.hasMatch(_passwordController.text.trim())) {
      _showSnack("Mật khẩu quá yếu (phải gồm chữ hoa, chữ thường, số, ký tự đặc biệt)");
      return false;
    }

    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      _showSnack("Mật khẩu nhập lại không trùng");
      return false;
    }

    if (!_agreeTerms) {
      _showSnack("Bạn cần đồng ý với Điều khoản sử dụng");
      return false;
    }

    if (_licenseNumberController.text.trim().isEmpty) {
      _showSnack("Biển số xe không được để trống");
      return false;
    }

    if (_avatar == null) {
      _showSnack("Yêu cầu tài xế phải có ảnh đại diên chân dung");
      return false;
    }

    return true;
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) return;

    setState(() => _loading = true);

    final res = await ApiService.driverRegister(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      avatarFilePath: _avatar!.path,
      licenseNumber: _licenseNumberController.text.trim(),
    );

    setState(() => _loading = false);

    if (res.statusCode == 200 || res.statusCode == 201) {
      _showSnack("Đăng ký thành công!", color: Theme.of(context).colorScheme.secondary);
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
        );
      });
    } else {
      try {
        final json = jsonDecode(res.body);
        _showSnack(json["message"] ?? "Lỗi đăng ký");
      } catch (_) {
        _showSnack("Đăng ký thất bại (${res.statusCode})");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Đăng ký Tài khoản",
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            color: theme.colorScheme.secondary, // GOLD title
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
                  _buildAvatarSection(theme),
                  const SizedBox(height: 24),

                  _buildInfoCard(
                    theme: theme,
                    title: "Thông tin cá nhân",
                    children: [
                      _buildTextField(
                        controller: _fullNameController,
                        hint: "Họ và tên",
                        icon: Icons.badge,
                        isPhone: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        hint: "Email",
                        icon: Icons.email,
                        isPhone: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _licenseNumberController,
                        hint: "Biển số xe",
                        icon: Icons.directions_car,
                        isPhone: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildInfoCard(
                    theme: theme,
                    title: "Thông tin liên hệ",
                    children: [
                      _buildTextField(
                        controller: _phoneController,
                        hint: "Số điện thoại",
                        icon: Icons.phone,
                        isPhone: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _confirmPhoneController,
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
                      _buildPasswordTextField(
                        theme: theme,
                        controller: _passwordController,
                        hint: "Mật khẩu",
                        isConfirm: false,
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordTextField(
                        theme: theme,
                        controller: _confirmPasswordController,
                        hint: "Nhập lại mật khẩu",
                        isConfirm: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildTermsAndButton(theme),

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
                        color: theme.colorScheme.secondary, // GOLD link
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            if (_loading)
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

  // Avatar section
  Widget _buildAvatarSection(ThemeData theme) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: theme.colorScheme.surface.withOpacity(0.6),
            backgroundImage: _avatar != null ? FileImage(File(_avatar!.path)) : null,
            child: _avatar == null
                ? Icon(Icons.person, size: 55, color: theme.colorScheme.onSurface.withOpacity(0.6))
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: InkWell(
              onTap: _loading ? null : _pickAvatar,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _loading ? theme.disabledColor : theme.colorScheme.secondary,
                child: Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: theme.colorScheme.onSecondary, // theo scheme (black)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Group card
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
                color: theme.colorScheme.secondary, // GOLD section title
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPhone,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
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
        prefixIcon: Icon(icon, color: theme.colorScheme.secondary),
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

  Widget _buildPasswordTextField({
    required ThemeData theme,
    required TextEditingController controller,
    required String hint,
    required bool isConfirm,
  }) {
    final isObscure = isConfirm ? _obscureConfirmPassword : _obscurePassword;
    final toggleObscure = isConfirm
        ? () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)
        : () => setState(() => _obscurePassword = !_obscurePassword);

    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.75),
        ),
        prefixIcon: Icon(Icons.lock, color: theme.colorScheme.secondary),
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          onPressed: toggleObscure,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.65),
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

  Widget _buildTermsAndButton(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              value: _agreeTerms,
              activeColor: theme.colorScheme.secondary,
              checkColor: theme.colorScheme.onSecondary,
              side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.5)),
              onChanged: (v) => setState(() => _agreeTerms = v ?? false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  );
                },
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
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _handleRegister,
            child: _loading
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