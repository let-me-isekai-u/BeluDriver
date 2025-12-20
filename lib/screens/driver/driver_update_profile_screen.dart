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
  State<DriverUpdateProfileScreen> createState() => _DriverUpdateProfileScreenState();
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
    _licenseNumberController = TextEditingController(text: widget.profile.licenseNumber);
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
      Navigator.pop(context, true); // trả về để reload profile
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cập nhật hồ sơ'),
        centerTitle: true,
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
                      radius: 55,
                      backgroundColor: primary.withOpacity(0.15),
                      backgroundImage: _avatar != null
                          ? FileImage(File(_avatar!.path))
                          : (widget.profile.avatarUrl.isNotEmpty
                          ? NetworkImage(widget.profile.avatarUrl)
                          : null) as ImageProvider?,
                      child: (_avatar == null && widget.profile.avatarUrl.isEmpty)
                          ? Icon(Icons.person, size: 55, color: primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: InkWell(
                        onTap: _loading ? null : _pickAvatar,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: primary,
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                _buildTextField(_fullNameController, 'Họ và tên', Icons.badge),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'Email', Icons.email),
                const SizedBox(height: 16),
                _buildTextField(_licenseNumberController, 'Biển số xe', Icons.directions_car),

                const SizedBox(height: 30),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _handleUpdate,
                    child: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Lưu thay đổi'),
                  ),
                )
              ],
            ),
          ),

          if (_loading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
