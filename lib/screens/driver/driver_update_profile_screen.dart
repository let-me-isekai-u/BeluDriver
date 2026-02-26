import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver/driver_profile_model.dart';
import '../../services/api_service.dart';

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
    _licenseNumberController =
        TextEditingController(text: widget.profile.licenseNumber);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Cập nhật hồ sơ',
          style: TextStyle(
            color: theme.colorScheme.secondary, // ✅ gold like sample
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor:
                      theme.colorScheme.secondary.withOpacity(0.15),
                      backgroundImage: _avatar != null
                          ? FileImage(File(_avatar!.path))
                          : (widget.profile.avatarUrl.isNotEmpty
                          ? NetworkImage(widget.profile.avatarUrl)
                          : null) as ImageProvider?,
                      child: (_avatar == null &&
                          widget.profile.avatarUrl.isEmpty)
                          ? Icon(
                        Icons.person,
                        size: 70,
                        color: theme.colorScheme.secondary,
                      )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: InkWell(
                        onTap: _loading ? null : _pickAvatar,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.secondary,
                          child: const Icon(Icons.camera_alt,
                              size: 18, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                _buildTextField(
                  controller: _fullNameController,
                  label: 'Họ và tên',
                  icon: Icons.badge,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _licenseNumberController,
                  label: 'Biển số xe',
                  icon: Icons.directions_car,
                ),

                const SizedBox(height: 30),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      ),
                    )
                        : const Text(
                      'Lưu thay đổi',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
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
            )
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: theme.colorScheme.secondary),
        filled: true,
        fillColor: theme.colorScheme.surface, // ✅ no grey[100]
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
        ),
      ),
    );
  }
}