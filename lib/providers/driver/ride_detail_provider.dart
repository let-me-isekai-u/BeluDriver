import 'dart:convert';

import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/foundation.dart';

import '../../models/driver/ride_detail_model.dart';
import '../../services/api_service.dart';
import '../../services/api_response.dart';

class RideDetailProvider extends ChangeNotifier {
  RideDetailProvider({required this.rideId, required this.rideSource});

  final int rideId;
  final int rideSource;

  RideDetailModel? ride;
  String? actionError;
  bool isLoading = true;
  bool canStart = false;
  bool canComplete = false;
  bool _actionInFlight = false;

  Future<String> _getToken() async {
    return (await TokenStorage.instance.readAccessToken()) ?? '';
  }

  Future<void> fetchRideDetail() async {
    isLoading = true;
    canStart = false;
    canComplete = false;
    ride = null;
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
          final status = ride!.status;
          if (status == 2 || status == 3) {
            final permitted = await ApiService.canExecuteRide(
              accessToken: token,
              rideId: rideId,
              rideSource: rideSource,
              status: status,
            );
            canStart = permitted && status == 2;
            canComplete = permitted && status == 3;
          }
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
    if (!canStart || _actionInFlight) {
      actionError = 'Bạn chưa có quyền bắt đầu chuyến ở trạng thái hiện tại.';
      return false;
    }
    _actionInFlight = true;
    try {
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
    } catch (_) {
      actionError = 'Chưa xác nhận được kết quả. Vui lòng tải lại chuyến.';
      return false;
    } finally {
      _actionInFlight = false;
    }
  }

  Future<bool> completeRide() async {
    if (!canComplete || _actionInFlight) {
      actionError =
          'Bạn chưa có quyền hoàn thành chuyến ở trạng thái hiện tại.';
      return false;
    }
    _actionInFlight = true;
    try {
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
    } catch (_) {
      actionError = 'Chưa xác nhận được kết quả. Vui lòng tải lại chuyến.';
      return false;
    } finally {
      _actionInFlight = false;
    }
  }
}
