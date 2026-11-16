import 'package:flutter/material.dart';
import '../../services/v2/api_service.dart';
import '../../services/api_response.dart';

enum RegistrationField {
  fullName,
  email,
  licenseNumber,
  region,
  phone,
  confirmPhone,
  password,
  confirmPassword,
  terms,
  camera,
  otp,
}

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

  // Shared identity service: existing customer registration consumes a root
  // challengeId and a six-digit OTP. The server remains authoritative.
  static const otpLength = 6;
  static const stepFields = <List<RegistrationField>>[
    [
      RegistrationField.fullName,
      RegistrationField.email,
      RegistrationField.licenseNumber,
      RegistrationField.region,
    ],
    [
      RegistrationField.phone,
      RegistrationField.confirmPhone,
      RegistrationField.password,
      RegistrationField.confirmPassword,
    ],
    [RegistrationField.terms, RegistrationField.camera],
    [RegistrationField.otp],
  ];
  final otpController = TextEditingController();
  final Map<RegistrationField, String> fieldErrors = {};
  final Set<int> _validatedSteps = {};
  String? _challengeId;
  String? _challengeEmail;
  String? _challengePhone;
  String? apiError;
  bool registrationOutcomeUnknown = false;
  bool registrationCompleted = false;
  bool _disposed = false;
  int _identityRevision = 0;
  late String _lastEmail;
  late String _lastPhone;

  RegisterProvider() {
    _lastEmail = emailController.text.trim();
    _lastPhone = phoneController.text.trim();
    emailController.addListener(_identityChanged);
    phoneController.addListener(_identityChanged);
  }

  String? get challengeId => _challengeId;
  bool get hasMatchingChallenge =>
      _challengeId != null &&
      _challengeEmail == emailController.text.trim() &&
      _challengePhone == phoneController.text.trim();
  bool get canSubmit =>
      !loading && !registrationOutcomeUnknown && !registrationCompleted;
  String get maskedChallengeEmail {
    final email = _challengeEmail ?? emailController.text.trim();
    final at = email.indexOf('@');
    return at > 0
        ? '${email.substring(0, 1)}***${email.substring(at)}'
        : 'email đăng ký';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _clearChallenge() {
    _challengeId = null;
    _challengeEmail = null;
    _challengePhone = null;
    otpController.clear();
    fieldErrors.remove(RegistrationField.otp);
  }

  void _identityChanged() {
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    if (email == _lastEmail && phone == _lastPhone) return;
    _lastEmail = email;
    _lastPhone = phone;
    _identityRevision++;
    _clearChallenge();
    _notify();
  }

  static int stepForField(RegistrationField field) =>
      stepFields.indexWhere((fields) => fields.contains(field));

  void fieldChanged(RegistrationField field) {
    final step = stepForField(field);
    if (_validatedSteps.contains(step)) {
      for (final item in stepFields[step]) {
        final error = validateField(item);
        if (error == null) {
          fieldErrors.remove(item);
        } else {
          fieldErrors[item] = error;
        }
      }
    }
    if (!registrationOutcomeUnknown) apiError = null;
    _notify();
  }

  bool validateStep(int step) {
    _validatedSteps.add(step);
    for (final field in stepFields[step]) {
      final error = validateField(field);
      if (error == null) {
        fieldErrors.remove(field);
      } else {
        fieldErrors[field] = error;
      }
    }
    _notify();
    return !stepFields[step].any(fieldErrors.containsKey);
  }

  bool validateAllFields() {
    for (var step = 0; step < 3; step++) {
      validateStep(step);
    }
    return !stepFields
        .take(3)
        .expand((fields) => fields)
        .any(fieldErrors.containsKey);
  }

  RegistrationField? get firstInvalidField {
    for (final field in stepFields.expand((fields) => fields)) {
      if (fieldErrors.containsKey(field)) return field;
    }
    return null;
  }

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
    fieldChanged(RegistrationField.terms);
  }

  void setAgreeCamera(bool value) {
    agreeCamera = value;
    fieldChanged(RegistrationField.camera);
  }

  void setRegion(int? value) {
    selectedRegion = value;
    fieldChanged(RegistrationField.region);
  }

  String? validateField(RegistrationField field) {
    switch (field) {
      case RegistrationField.fullName:
        return fullNameController.text.trim().isEmpty
            ? 'Họ tên không được để trống'
            : null;
      case RegistrationField.email:
        return RegExp(
              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
            ).hasMatch(emailController.text.trim())
            ? null
            : 'Email không hợp lệ';
      case RegistrationField.licenseNumber:
        return licenseNumberController.text.trim().isEmpty
            ? 'Biển số xe không được để trống'
            : null;
      case RegistrationField.region:
        return selectedRegion == null ? 'Vui lòng chọn miền hoạt động' : null;
      case RegistrationField.phone:
        return RegExp(r'^[0-9]{9,11}$').hasMatch(phoneController.text.trim())
            ? null
            : 'Số điện thoại không hợp lệ';
      case RegistrationField.confirmPhone:
        if (confirmPhoneController.text.trim().isEmpty) {
          return 'Chưa nhập lại số điện thoại';
        }
        return phoneController.text.trim() != confirmPhoneController.text.trim()
            ? 'Số điện thoại nhập lại không trùng'
            : null;
      case RegistrationField.password:
        if (passwordController.text.trim().isEmpty) return 'Chưa nhập mật khẩu';
        return RegExp(
              r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
            ).hasMatch(passwordController.text.trim())
            ? null
            : 'Mật khẩu quá yếu (phải gồm chữ hoa, chữ thường, số, ký tự đặc biệt)';
      case RegistrationField.confirmPassword:
        if (confirmPasswordController.text.trim().isEmpty) {
          return 'Chưa nhập lại mật khẩu';
        }
        return passwordController.text.trim() !=
                confirmPasswordController.text.trim()
            ? 'Mật khẩu nhập lại không trùng'
            : null;
      case RegistrationField.terms:
        return agreeTerms ? null : 'Bạn cần đồng ý với Điều khoản sử dụng';
      case RegistrationField.camera:
        return agreeCamera
            ? null
            : 'Bạn cần xác nhận xe có gắn camera hành trình và hoạt động bình thường';
      case RegistrationField.otp:
        if (otpController.text.trim().isEmpty) {
          return 'Vui lòng nhập mã OTP email';
        }
        return RegExp(r'^[0-9]{6}$').hasMatch(otpController.text.trim())
            ? null
            : 'Mã OTP phải gồm 6 chữ số';
    }
  }

  /// Same validators as each Continue button; OTP is checked at its own step.
  String? validate() {
    for (final field in stepFields.take(3).expand((fields) => fields)) {
      final error = validateField(field);
      if (error != null) return error;
    }
    return null;
  }

  Future<bool> requestRegistrationChallenge() async {
    if (!canSubmit || !validateAllFields()) return false;
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final revision = _identityRevision;
    _clearChallenge();
    apiError = null;
    loading = true;
    _notify();
    try {
      final response = await ApiService.requestRegistrationChallenge(
        email: email,
        phone: phone,
      );
      if (_disposed) return false;
      if (revision != _identityRevision) {
        apiError =
            'Email hoặc số điện thoại đã thay đổi. Vui lòng yêu cầu mã mới.';
        return false;
      }
      final body = responseJson(response);
      final id = body?['challengeId'];
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body?['success'] != false &&
          id is String &&
          id.trim().isNotEmpty) {
        _challengeId = id.trim();
        _challengeEmail = email;
        _challengePhone = phone;
        return true;
      }
      apiError = apiErrorMessage(
        response,
        response.statusCode == 429
            ? 'Bạn đã yêu cầu mã quá nhiều lần. Vui lòng thử lại sau.'
            : 'Không lấy được mã xác minh email. Vui lòng thử lại.',
      );
      return false;
    } catch (_) {
      if (!_disposed) {
        apiError = 'Không thể kết nối để lấy mã xác minh. Vui lòng thử lại.';
      }
      return false;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> register({
    required void Function(String msg, {Color? color}) onSnack,
  }) async {
    if (!canSubmit) return false;
    if (!validateAllFields()) {
      onSnack(fieldErrors[firstInvalidField]!);
      return false;
    }
    if (!hasMatchingChallenge) {
      apiError =
          'Vui lòng yêu cầu mã xác minh cho email và số điện thoại hiện tại.';
      _notify();
      onSnack(apiError!);
      return false;
    }
    if (!validateStep(3)) {
      onSnack(fieldErrors[RegistrationField.otp]!);
      return false;
    }
    loading = true;
    apiError = null;
    _notify();
    try {
      final response = await ApiService.driverRegister(
        fullName: fullNameController.text.trim(),
        phone: _challengePhone!,
        email: _challengeEmail!,
        password: passwordController.text.trim(),
        licenseNumber: licenseNumberController.text.trim(),
        region: selectedRegion!,
        challengeId: _challengeId!,
        otp: otpController.text.trim(),
      );
      if (_disposed) return false;
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseJson(response)?['success'] != false) {
        registrationCompleted = true;
        return true;
      }
      if (response.statusCode >= 500 || response.statusCode == 408) {
        registrationOutcomeUnknown = true;
        apiError =
            'Chưa xác nhận được kết quả đăng ký. Vui lòng kiểm tra email hoặc đăng nhập trước khi thử lại.';
      } else {
        apiError = apiErrorMessage(
          response,
          'Đăng ký thất bại (${response.statusCode}). Vui lòng kiểm tra mã OTP và thông tin đăng ký.',
        );
      }
      onSnack(apiError!);
      return false;
    } catch (_) {
      if (_disposed) return false;
      registrationOutcomeUnknown = true;
      apiError =
          'Chưa xác nhận được kết quả đăng ký. Vui lòng kiểm tra email hoặc đăng nhập trước khi thử lại.';
      onSnack(apiError!);
      return false;
    } finally {
      loading = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    emailController.removeListener(_identityChanged);
    phoneController.removeListener(_identityChanged);
    otpController.dispose();
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
