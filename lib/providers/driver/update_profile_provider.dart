import 'dart:convert';

import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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
    required Future<String?> Function() readSmsCode,
    required bool changedEmail,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final accessToken = (await TokenStorage.instance.readAccessToken());

      if (accessToken == null || accessToken.isEmpty) {
        return 'Phiên đăng nhập đã hết hạn';
      }

      String? challengeId;
      String? otp;
      if (changedEmail) {
        challengeId = await ApiService.requestEmailChangeCode(
          accessToken: accessToken,
          email: email,
        );
        otp = await readSmsCode();
        if (otp == null) return '';
      }
      final res = await ApiService.updateProfile(
        accessToken: accessToken,
        fullName: fullName,
        email: email,
        challengeId: challengeId,
        otp: otp,
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
    } on FormatException catch (error) {
      return error.message;
    } catch (_) {
      return 'Không cập nhật được hồ sơ. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
