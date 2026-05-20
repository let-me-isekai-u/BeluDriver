import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver/ride_detail_model.dart';
import '../../services/api_service.dart';

class RideDetailProvider extends ChangeNotifier {
  RideDetailProvider({
    required this.rideId,
    required this.rideSource,
  });

  final int rideId;
  final int rideSource;

  RideDetailModel? ride;
  bool isLoading = true;

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? '';
  }

  Future<void> fetchRideDetail() async {
    isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      final res = await ApiService.getRideDetail(
        accessToken: token,
        rideId: rideId,
        rideSource: rideSource,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          ride = RideDetailModel.fromJson(body['data']);
        } else {
          ride = null;
        }
      }
    } catch (e) {
      debugPrint("🔥 Lỗi fetch detail: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startRide() async {
    final token = await _getToken();
    if (token.isEmpty) return false;

    final res = await ApiService.startRide(
      accessToken: token,
      rideId: rideId,
      rideSource: rideSource,
    );

    if (res.statusCode == 200) {
      await fetchRideDetail();
      return true;
    }
    return false;
  }

  Future<bool> completeRide() async {
    final token = await _getToken();
    if (token.isEmpty) return false;

    final res = await ApiService.completeRide(
      accessToken: token,
      rideId: rideId,
      rideSource: rideSource,
    );

    if (res.statusCode == 200) {
      await fetchRideDetail();
      return true;
    }
    return false;
  }
}
