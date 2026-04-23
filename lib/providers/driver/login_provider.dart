import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/firebase_notification_service.dart';
import '../../services/kyc_service.dart';

class LoginProvider extends ChangeNotifier {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  Future<String?> login() async {
    final String phone = phoneController.text.trim();
    final String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      return "Vui lòng nhập đầy đủ thông tin";
    }

    isLoading = true;
    notifyListeners();

    try {
      String? deviceToken = await FirebaseNotificationService.getDeviceToken();
      final String tokenToSend = deviceToken ?? "";

      final res = await ApiService.driverLogin(
        phone: phone,
        password: password,
        deviceToken: tokenToSend,
      );

      debugPrint('[LOGIN] statusCode = ${res.statusCode}');
      debugPrint('[LOGIN] body = ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final accessToken = data["accessToken"] ?? "";
        final refreshToken = data["refreshToken"] ?? "";
        final fullName = data["fullName"] ?? "";
        final int kycStatus = (data["kycStatus"] as num?)?.toInt() ?? 0;
        final String kycStatusText = data["kycStatusText"]?.toString() ?? "";
        final String? kycRejectReason = data["kycRejectReason"]?.toString();

        debugPrint('[LOGIN] kycStatus = $kycStatus');
        debugPrint('[LOGIN] kycStatusText = $kycStatusText');
        debugPrint('[LOGIN] kycRejectReason = $kycRejectReason');

        if (accessToken.isEmpty) {
          return "Server không trả về accessToken";
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("accessToken", accessToken);
        await prefs.setString("refreshToken", refreshToken);
        await prefs.setString("fullName", fullName);

        await prefs.setInt("loginKycStatus", kycStatus);
        await prefs.setString("loginKycStatusText", kycStatusText);
        await prefs.setString("loginKycRejectReason", kycRejectReason ?? "");

        final bool shouldShowKycPopup = (kycStatus == 0 || kycStatus == 3);
        await prefs.setBool("shouldShowKycPopup", shouldShowKycPopup);

        debugPrint('[LOGIN] shouldShowKycPopup = $shouldShowKycPopup');

        await prefs.remove("cachedKycJson");

        if (kycStatus == 3) {
          try {
            final kycRes = await KYCService.getKYC(accessToken);
            debugPrint('[LOGIN] preload GET /kyc statusCode = ${kycRes.statusCode}');
            debugPrint('[LOGIN] preload GET /kyc body = ${kycRes.body}');

            if (kycRes.statusCode >= 200 && kycRes.statusCode < 300) {
              await prefs.setString("cachedKycJson", kycRes.body);
              debugPrint('[LOGIN] cachedKycJson saved');
            }
          } catch (e) {
            debugPrint('[LOGIN] preload KYC failed: $e');
          }
        }

        return null;
      } else {
        final err = jsonDecode(res.body);
        return err["message"] ?? "Sai tài khoản hoặc mật khẩu";
      }
    } catch (e) {
      debugPrint('[LOGIN] error = $e');
      return "Lỗi kết nối: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}