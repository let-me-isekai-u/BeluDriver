import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_theme.dart';
import '../../models/driver/driver_profile_model.dart';
import '../../services/api_service.dart';
import '../../widgets/driver_ui.dart';

class DriverUpdateProfileScreen extends StatefulWidget {
  final DriverProfileModel profile;

  const DriverUpdateProfileScreen({super.key, required this.profile});

  @override
  State<DriverUpdateProfileScreen> createState() =>
      _DriverUpdateProfileScreenState();
}

class _DriverUpdateProfileScreenState extends State<DriverUpdateProfileScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _licenseNumberController;

  XFile? _avatar;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _emailController = TextEditingController(text: widget.profile.email);
    _licenseNumberController = TextEditingController(
      text: widget.profile.licenseNumber,
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatar = picked);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleUpdate() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null || accessToken.isEmpty) {
      setState(() => _loading = false);
      _showSnack('Phiên đăng nhập đã hết hạn');
      return;
    }

    final res = await ApiService.updateProfile(
      accessToken: accessToken,
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      licenseNumber: _licenseNumberController.text.trim(),
      avatarFilePath: _avatar?.path,
    );

    setState(() => _loading = false);

    if (res.statusCode == 200) {
      _showSnack('Cập nhật thông tin thành công');
      if (mounted) Navigator.pop(context, true);
    } else {
      try {
        final json = jsonDecode(res.body);
        _showSnack(json['message'] ?? 'Cập nhật thất bại');
      } catch (_) {
        _showSnack('Cập nhật thất bại (${res.statusCode})');
      }
    }
  }

  ImageProvider? _avatarProvider() {
    if (_avatar != null) {
      return FileImage(File(_avatar!.path));
    }
    if (widget.profile.avatarUrl.isNotEmpty) {
      return NetworkImage(widget.profile.avatarUrl);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Cập nhật hồ sơ',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -70,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.06),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(theme),
                const SizedBox(height: 16),
                DriverSectionCard(
                  title: "Thông tin hiển thị",
                  subtitle:
                      "Chỉnh sửa hồ sơ cá nhân, email liên hệ và biển số xe.",
                  icon: Icons.edit_note_rounded,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Họ và tên',
                        hint: 'Nhập họ tên tài xế',
                        icon: Icons.badge_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Nhập email liên hệ',
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _licenseNumberController,
                        label: 'Biển số xe',
                        hint: 'Ví dụ: 51A-12345',
                        icon: Icons.directions_car_filled_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _handleUpdate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.black87,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_loading ? 'Đang cập nhật...' : 'Lưu thay đổi'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.surfaceGreen.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: theme.colorScheme.secondary.withValues(
                  alpha: 0.14,
                ),
                backgroundImage: _avatarProvider(),
                child: _avatarProvider() == null
                    ? Icon(
                        Icons.person_rounded,
                        size: 46,
                        color: theme.colorScheme.secondary,
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _loading ? null : _pickAvatar,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DriverPill(
                  label: "Hồ sơ tài xế",
                  icon: Icons.workspace_premium_rounded,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.profile.fullName.isEmpty
                      ? "Cập nhật thông tin"
                      : widget.profile.fullName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Ảnh đại diện và thông tin cơ bản sẽ được hiển thị xuyên suốt ứng dụng.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
      decoration: driverInputDecoration(
        theme,
        label: label,
        hint: hint,
        icon: icon,
      ),
    );
  }
}
