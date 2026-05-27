import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/v2/api_service.dart';

class RegisterProvider extends ChangeNotifier {
  static const Map<int, String> regionOptions = {
    1: 'Miền Bắc',
    2: 'Miền Trung',
  };

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController confirmPhoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController licenseNumberController = TextEditingController();

  bool agreeTerms = false;
  bool agreeCamera = false;
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  int? selectedRegion;

  bool get canSubmit => agreeTerms && agreeCamera && !loading;

  void toggleObscurePassword() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void toggleObscureConfirmPassword() {
    obscureConfirmPassword = !obscureConfirmPassword;
    notifyListeners();
  }

  void setAgreeTerms(bool value) {
    agreeTerms = value;
    notifyListeners();
  }

  void setAgreeCamera(bool value) {
    agreeCamera = value;
    notifyListeners();
  }

  void setRegion(int? value) {
    selectedRegion = value;
    notifyListeners();
  }

  /// Returns null nếu hợp lệ, trả về thông báo lỗi nếu không hợp lệ
  String? validate() {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    final phoneRegex = RegExp(r'^[0-9]{9,11}$');
    final strongPassRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );

    if (fullNameController.text.trim().isEmpty) {
      return "Họ tên không được để trống";
    }
    if (!emailRegex.hasMatch(emailController.text.trim())) {
      return "Email không hợp lệ";
    }
    if (!phoneRegex.hasMatch(phoneController.text.trim())) {
      return "Số điện thoại không hợp lệ";
    }
    if (phoneController.text.trim() != confirmPhoneController.text.trim()) {
      return "Số điện thoại nhập lại không trùng";
    }
    if (!strongPassRegex.hasMatch(passwordController.text.trim())) {
      return "Mật khẩu quá yếu (phải gồm chữ hoa, chữ thường, số, ký tự đặc biệt)";
    }
    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      return "Mật khẩu nhập lại không trùng";
    }
    if (!agreeTerms) {
      return "Bạn cần đồng ý với Điều khoản sử dụng";
    }
    if (!agreeCamera) {
      return "Bạn cần xác nhận xe có gắn camera hành trình và hoạt động bình thường";
    }
    if (licenseNumberController.text.trim().isEmpty) {
      return "Biển số xe không được để trống";
    }
    if (selectedRegion == null) {
      return "Vui lòng chọn miền hoạt động";
    }
    return null;
  }

  /// Trả về `true` nếu đăng ký thành công
  Future<bool> register({
    required void Function(String msg, {Color? color}) onSnack,
  }) async {
    final error = validate();
    if (error != null) {
      onSnack(error);
      return false;
    }

    loading = true;
    notifyListeners();

    final res = await ApiService.driverRegister(
      fullName: fullNameController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      licenseNumber: licenseNumberController.text.trim(),
      region: selectedRegion!,
    );

    loading = false;
    notifyListeners();

    if (res.statusCode == 200 || res.statusCode == 201) {
      return true;
    } else {
      try {
        final json = jsonDecode(res.body);
        onSnack(json["message"] ?? "Lỗi đăng ký");
      } catch (_) {
        onSnack("Đăng ký thất bại (${res.statusCode})");
      }
      return false;
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    confirmPhoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    licenseNumberController.dispose();
    super.dispose();
  }
}
