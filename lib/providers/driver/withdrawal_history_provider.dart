import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver/withdrawal_history_model.dart';
import '../../services/api_service.dart';

class WithdrawalHistoryProvider extends ChangeNotifier {
  List<WithdrawalHistoryModel> history = [];
  bool isLoading = true;
  String? errorMessage;

  Future<void> loadHistory() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final res = await ApiService.getWithdrawalHistory(accessToken: token);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          history = (body['data'] as List)
              .map((e) => WithdrawalHistoryModel.fromJson(e))
              .toList();
        } else {
          history = [];
        }
      } else {
        history = [];
        errorMessage = "Không thể tải lịch sử rút tiền.";
      }
    } catch (e) {
      debugPrint("Error loadHistory: $e");
      errorMessage = "Không thể tải lịch sử rút tiền. Vui lòng thử lại!";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
