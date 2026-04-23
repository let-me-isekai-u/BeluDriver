import 'package:flutter/foundation.dart';
import 'package:beludriver_app/services/api_service.dart';

class DepositProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _success = false;
  String? _errorMessage;
  String? _depositContent;

  bool get isLoading => _isLoading;
  bool get success => _success;
  String? get errorMessage => _errorMessage;
  String? get depositContent => _depositContent;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void resetState() {
    _isLoading = false;
    _success = false;
    _errorMessage = null;
    _depositContent = null;
    notifyListeners();
  }

  /// Tạo yêu cầu nạp tiền
  /// API 4.1
  Future<bool> createDepositRequest({
    required String accessToken,
    required int amount,
  }) async {
    _setLoading(true);
    _success = false;
    _errorMessage = null;
    _depositContent = null;

    try {
      final response = await ApiService.createDepositRequest(
        accessToken: accessToken,
        amount: amount,
      );

      final data = ApiService.safeDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        _success = true;
        _depositContent = data["data"]?["content"]?.toString();
        notifyListeners();
        return true;
      }

      _success = false;
      _errorMessage =
          data["message"]?.toString() ?? "Không thể tạo yêu cầu nạp tiền";
      notifyListeners();
      return false;
    } catch (e) {
      _success = false;
      _errorMessage = "Lỗi tạo yêu cầu nạp tiền: $e";
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Hủy yêu cầu nạp tiền
  /// API 4.2
  Future<bool> cancelDepositRequest({
    required String accessToken,
    required int depositId,
  }) async {
    _setLoading(true);
    _success = false;
    _errorMessage = null;

    try {
      final response = await ApiService.cancelDepositRequest(
        accessToken: accessToken,
        depositId: depositId,
      );

      final data = ApiService.safeDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        _success = true;
        notifyListeners();
        return true;
      }

      _success = false;
      _errorMessage = data["message"]?.toString() ??
          "Không thể hủy yêu cầu nạp tiền";
      notifyListeners();
      return false;
    } catch (e) {
      _success = false;
      _errorMessage = "Lỗi hủy yêu cầu nạp tiền: $e";
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }
}