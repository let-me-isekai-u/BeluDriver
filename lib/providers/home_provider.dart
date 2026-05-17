import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver/driver_profile_model.dart';
import '../models/driver_onboarding_status_dto.dart';
import '../services/api_service.dart';

class HomeProvider extends ChangeNotifier {
  DriverProfileModel? _profile;
  DriverOnboardingStatusDto? _onboardingStatus;

  bool _isLoadingProfile = true;
  bool _isLoadingOnboardingStatus = true;
  bool _hasCheckedKycPopup = false;

  bool _shouldShowKycPopup = false;
  bool _shouldShowRegisterRoutePopup = false;

  DriverProfileModel? get profile => _profile;
  DriverOnboardingStatusDto? get onboardingStatus => _onboardingStatus;

  bool get isLoadingProfile => _isLoadingProfile;
  bool get isLoadingOnboardingStatus => _isLoadingOnboardingStatus;
  bool get hasCheckedKycPopup => _hasCheckedKycPopup;

  bool get shouldShowKycPopup => _shouldShowKycPopup;
  bool get shouldShowRegisterRoutePopup => _shouldShowRegisterRoutePopup;

  bool get hasRegisteredRoute => _onboardingStatus?.hasRegisteredRoute ?? false;

  int get kycStatus => _onboardingStatus?.kycStatus ?? 0;
  String get nextStep => _onboardingStatus?.nextStep ?? '';
  String get kycStatusTextSafe =>
      _onboardingStatus?.kycStatusText.trim().isNotEmpty == true
      ? _onboardingStatus!.kycStatusText
      : 'Chưa hoàn tất';

  String get nextStepLabel {
    switch (nextStep.trim().toLowerCase()) {
      case 'select_route':
      case 'register_route':
        return 'Đăng ký tuyến hoạt động';
      case 'submit_kyc':
        return 'Hoàn tất hồ sơ KYC';
      case 'resubmit_kyc':
        return 'Bổ sung và gửi lại KYC';
      case 'waiting_kyc_approval':
        return 'Chờ hệ thống duyệt hồ sơ';
      default:
        return 'Kiểm tra thông tin tài khoản';
    }
  }

  bool get kycPendingReview =>
      nextStep == 'waiting_kyc_approval' || kycStatus == 1;

  bool get isReadyForPopupCheck =>
      !_isLoadingProfile &&
      !_isLoadingOnboardingStatus &&
      _hasCheckedKycPopup &&
      _profile != null &&
      _onboardingStatus != null;

  Future<void> initialize() async {
    await Future.wait([
      fetchProfile(),
      fetchOnboardingStatus(),
      loadKycPopupFlag(),
    ]);

    _syncOnboardingFlags();
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    _isLoadingProfile = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      if (token.isEmpty) return;

      final res = await ApiService.getDriverProfile(accessToken: token);

      debugPrint("[HOME_PROVIDER] profile statusCode = ${res.statusCode}");
      debugPrint("[HOME_PROVIDER] profile body = ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        _profile = DriverProfileModel.fromJson(decoded);
      }
    } catch (e) {
      debugPrint("[HOME_PROVIDER] fetchProfile error: $e");
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> fetchOnboardingStatus() async {
    _isLoadingOnboardingStatus = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      if (token.isEmpty) return;

      final data = await ApiService.getOnboardingStatus(token);

      if (data != null) {
        _onboardingStatus = data;

        debugPrint("[HOME_PROVIDER] onboarding.driverId = ${data.driverId}");
        debugPrint(
          "[HOME_PROVIDER] onboarding.hasRegisteredRoute = ${data.hasRegisteredRoute}",
        );
        debugPrint(
          "[HOME_PROVIDER] onboarding.selectedProvinceCount = ${data.selectedProvinceCount}",
        );
        debugPrint("[HOME_PROVIDER] onboarding.kycStatus = ${data.kycStatus}");
        debugPrint(
          "[HOME_PROVIDER] onboarding.kycStatusText = ${data.kycStatusText}",
        );
        debugPrint(
          "[HOME_PROVIDER] onboarding.kycRejectReason = ${data.kycRejectReason}",
        );
        debugPrint(
          "[HOME_PROVIDER] onboarding.canReceiveRide = ${data.canReceiveRide}",
        );
        debugPrint("[HOME_PROVIDER] onboarding.nextStep = ${data.nextStep}");
      }
    } catch (e) {
      debugPrint("[HOME_PROVIDER] fetchOnboardingStatus error: $e");
    } finally {
      _isLoadingOnboardingStatus = false;
      _syncOnboardingFlags();
      notifyListeners();
    }
  }

  void _syncOnboardingFlags() {
    final step = (_onboardingStatus?.nextStep ?? '').trim().toLowerCase();

    _shouldShowRegisterRoutePopup =
        step == 'select_route' || step == 'register_route';

    _shouldShowKycPopup = step == 'submit_kyc' || step == 'resubmit_kyc';

    debugPrint("[HOME_PROVIDER] nextStep = $step");
    debugPrint(
      "[HOME_PROVIDER] shouldShowRegisterRoutePopup = $_shouldShowRegisterRoutePopup",
    );
    debugPrint("[HOME_PROVIDER] shouldShowKycPopup = $_shouldShowKycPopup");
  }

  Future<void> refreshProfile() async {
    await Future.wait([
      fetchProfile(),
      fetchOnboardingStatus(),
      loadKycPopupFlag(),
    ]);

    _syncOnboardingFlags();
    notifyListeners();
  }

  Future<void> loadKycPopupFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedShouldShowRegisterRoutePopup =
          prefs.getBool("shouldShowRegisterRoutePopup") ?? false;
      final savedShouldShowKycPopup =
          prefs.getBool("shouldShowKycPopup") ?? false;

      final loginKycStatus = prefs.getInt("loginKycStatus");
      final loginKycStatusText = prefs.getString("loginKycStatusText");
      final loginKycRejectReason = prefs.getString("loginKycRejectReason");
      final loginNextStep = prefs.getString("loginNextStep");
      final loginHasRegisteredRoute = prefs.getBool("loginHasRegisteredRoute");
      final loginSelectedProvinceCount = prefs.getInt(
        "loginSelectedProvinceCount",
      );
      final loginCanReceiveRide = prefs.getBool("loginCanReceiveRide");
      final kycPendingReview = prefs.getBool("kycPendingReview");

      debugPrint(
        "[HOME_PROVIDER] saved shouldShowRegisterRoutePopup = $savedShouldShowRegisterRoutePopup",
      );
      debugPrint(
        "[HOME_PROVIDER] saved shouldShowKycPopup = $savedShouldShowKycPopup",
      );
      debugPrint("[HOME_PROVIDER] loginKycStatus = $loginKycStatus");
      debugPrint("[HOME_PROVIDER] loginKycStatusText = $loginKycStatusText");
      debugPrint(
        "[HOME_PROVIDER] loginKycRejectReason = $loginKycRejectReason",
      );
      debugPrint("[HOME_PROVIDER] loginNextStep = $loginNextStep");
      debugPrint(
        "[HOME_PROVIDER] loginHasRegisteredRoute = $loginHasRegisteredRoute",
      );
      debugPrint(
        "[HOME_PROVIDER] loginSelectedProvinceCount = $loginSelectedProvinceCount",
      );
      debugPrint("[HOME_PROVIDER] loginCanReceiveRide = $loginCanReceiveRide");
      debugPrint("[HOME_PROVIDER] kycPendingReview = $kycPendingReview");
    } catch (e) {
      debugPrint("[HOME_PROVIDER] loadKycPopupFlag error: $e");
    } finally {
      _hasCheckedKycPopup = true;
      notifyListeners();
    }
  }

  Future<void> markKycPopupShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("shouldShowKycPopup", false);
      _shouldShowKycPopup = false;
      notifyListeners();

      debugPrint(
        "[HOME_PROVIDER] Popup shown -> shouldShowKycPopup set to false",
      );
    } catch (e) {
      debugPrint("[HOME_PROVIDER] markKycPopupShown error: $e");
    }
  }

  Future<void> markRegisterRoutePopupShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("shouldShowRegisterRoutePopup", false);
      _shouldShowRegisterRoutePopup = false;
      notifyListeners();

      debugPrint(
        "[HOME_PROVIDER] Popup shown -> shouldShowRegisterRoutePopup set to false",
      );
    } catch (e) {
      debugPrint("[HOME_PROVIDER] markRegisterRoutePopupShown error: $e");
    }
  }
}
