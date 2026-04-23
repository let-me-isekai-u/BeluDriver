import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/driver/driver_profile_model.dart';
import '../../models/driver_onboarding_status_dto.dart';
import '../../services/api_service.dart';

class ProfileProvider extends ChangeNotifier {
  DriverProfileModel? profile;
  DriverOnboardingStatusDto? onboardingStatus;
  bool loading = true;

  Future<bool> loadProfile() async {
    try {
      loading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');

      if (accessToken == null || accessToken.isEmpty) {
        loading = false;
        notifyListeners();
        return false;
      }

      final profileRes = await ApiService.getDriverProfile(
        accessToken: accessToken,
      );

      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        profile = DriverProfileModel.fromJson(data);
      } else {
        profile = null;
      }

      onboardingStatus = await ApiService.getOnboardingStatus(accessToken);

      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      profile = null;
      onboardingStatus = null;
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }

    try {
      final res = await ApiService.deleteAccount(accessToken: accessToken);

      if (res.statusCode == 200) {
        await prefs.clear();
        profile = null;
        onboardingStatus = null;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken != null && accessToken.isNotEmpty) {
      await ApiService.Driverlogout(accessToken);
    }

    await prefs.clear();
    profile = null;
    onboardingStatus = null;
    notifyListeners();
  }

  Future<bool> openZalo() async {
    final Uri zaloUrl = Uri.parse('https://zalo.me/0379550130');

    if (await canLaunchUrl(zaloUrl)) {
      await launchUrl(zaloUrl, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  Future<bool> callSupport() async {
    final uri = Uri.parse('tel:0823416820');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}