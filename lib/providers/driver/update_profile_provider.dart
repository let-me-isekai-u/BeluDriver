import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';

class UpdateProfileProvider extends ChangeNotifier {
  XFile? avatar;
  bool isLoading = false;

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      avatar = picked;
      notifyListeners();
    }
  }

  Future<String?> updateProfile({
    required String fullName,
    required String email,
    required String licenseNumber,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');

      if (accessToken == null || accessToken.isEmpty) {
        return 'Phiên đăng nhập đã hết hạn';
      }

      final res = await ApiService.updateProfile(
        accessToken: accessToken,
        fullName: fullName,
        email: email,
        licenseNumber: licenseNumber,
        avatarFilePath: avatar?.path,
      );

      if (res.statusCode == 200) {
        return null;
      }

      try {
        final json = jsonDecode(res.body);
        return json['message'] ?? 'Cập nhật thất bại';
      } catch (_) {
        return 'Cập nhật thất bại (${res.statusCode})';
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
