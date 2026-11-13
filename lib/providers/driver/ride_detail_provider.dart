import 'dart:convert';

import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/foundation.dart';

import '../../models/driver/ride_detail_model.dart';
import '../../services/api_service.dart';
import '../../services/api_response.dart';

class RideDetailProvider extends ChangeNotifier {
  RideDetailProvider({
    required this.rideId,
    required this.rideSource,
  });

  final int rideId;
  final int rideSource;

  RideDetailModel? ride;
  String? actionError;
  bool isLoading = true;

  Future<String> _getToken() async {
    return (await TokenStorage.instance.readAccessToken()) ?? '';
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
    actionError = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    final token = await _getToken();
    if (token.isEmpty) return false;

    final res = await ApiService.startRide(
      accessToken: token,
      rideId: rideId,
      rideSource: rideSource,
    );

    if (res.statusCode == 200) {
      actionError = null;
      await fetchRideDetail();
      return true;
    }
    actionError = apiErrorMessage(res, 'Không thể bắt đầu chuyến đi.');
    return false;
  }

  Future<bool> completeRide() async {
    actionError = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    final token = await _getToken();
    if (token.isEmpty) return false;

    final res = await ApiService.completeRide(
      accessToken: token,
      rideId: rideId,
      rideSource: rideSource,
    );

    if (res.statusCode == 200) {
      actionError = null;
      await fetchRideDetail();
      return true;
    }
    actionError = apiErrorMessage(res, 'Không thể hoàn thành chuyến đi.');
    return false;
  }
}
