import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';

class WalletHistoryProvider extends ChangeNotifier {
  List<dynamic> transactions = [];
  bool isLoading = true;
  String? errorMessage;
  String currentBalance = "0";

  Future<void> fetchData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      if (token.isEmpty) {
        errorMessage = "Phiên đăng nhập đã hết hạn.";
        return;
      }

      final profileRes = await ApiService.getDriverProfile(accessToken: token);
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        final dynamic wallet = profileData['wallet'];
        if (wallet is num) {
          currentBalance = wallet.toStringAsFixed(0);
        } else {
          currentBalance = (double.tryParse(wallet?.toString() ?? '') ?? 0)
              .toStringAsFixed(0);
        }
      }

      final historyRes = await ApiService.getWalletHistory(accessToken: token);
      if (historyRes.statusCode == 200) {
        final Map<String, dynamic> historyData = jsonDecode(historyRes.body);
        if (historyData['success'] == true) {
          transactions = historyData['data'] ?? [];
        }
      } else {
        errorMessage = "Lỗi tải lịch sử giao dịch (${historyRes.statusCode})";
      }
    } catch (e) {
      errorMessage = "Đã xảy ra lỗi: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
