import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/routes/register_route_model.dart';
import '../../services/kyc_service.dart';

class RegisterRouteProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<RouteOptionModel> _routeOptions = [];
  RegisterRoutesResponseModel? _routesData;

  final List<int> _selectedProvinceIds = [];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  List<RouteOptionModel> get routeOptions => _routeOptions;
  RegisterRoutesResponseModel? get routesData => _routesData;
  List<int> get selectedProvinceIds => List.unmodifiable(_selectedProvinceIds);

  int get maxProvinceCount => _routesData?.maxProvinceCount ?? 3;

  List<SelectedProvinceModel> get selectedProvinces =>
      _routesData?.selectedProvinces ?? [];

  List<DriverRouteModel> get runtimeRoutes => _routesData?.routes ?? [];

  OnboardingModel? get onboarding => _routesData?.onboarding;

  bool isProvinceSelected(int provinceId) {
    return _selectedProvinceIds.contains(provinceId);
  }

  bool canSelectMore() {
    return _selectedProvinceIds.length < maxProvinceCount;
  }

  void setSelectedProvinceIds(List<int> ids) {
    _selectedProvinceIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void toggleProvince(int provinceId) {
    if (_selectedProvinceIds.contains(provinceId)) {
      _selectedProvinceIds.remove(provinceId);
    } else {
      if (_selectedProvinceIds.length >= maxProvinceCount) return;
      _selectedProvinceIds.add(provinceId);
    }
    notifyListeners();
  }

  void clearSelectedProvinces() {
    _selectedProvinceIds.clear();
    notifyListeners();
  }

  Future<bool> fetchRouteOptions(String accessToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await KYCService.getRouteOptions(accessToken);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body);

        _routeOptions = data
            .map((e) => RouteOptionModel.fromJson(e))
            .toList();

        return true;
      } else {
        _errorMessage = _extractMessage(response.body) ??
            'Không thể tải danh sách tuyến.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi tải route options: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> fetchRoutes(String accessToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await KYCService.getRoutes(accessToken);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        _routesData = RegisterRoutesResponseModel.fromJson(data);

        _selectedProvinceIds
          ..clear()
          ..addAll(
            _routesData!.selectedProvinces.map((e) => e.provinceId),
          );

        return true;
      } else {
        _errorMessage =
            _extractMessage(response.body) ?? 'Không thể tải thông tin tuyến.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi tải routes: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateRoutes({
    required String accessToken,
    List<int>? provinceIds,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ids = provinceIds ?? _selectedProvinceIds;

      if (ids.length > 3) {
        _errorMessage = 'Chỉ được chọn tối đa 3 tỉnh.';
        return false;
      }

      final response = await KYCService.updateRoutes(
        accessToken: accessToken,
        provinceIds: ids,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        _routesData = RegisterRoutesResponseModel.fromJson(data);

        _selectedProvinceIds
          ..clear()
          ..addAll(
            _routesData!.selectedProvinces.map((e) => e.provinceId),
          );

        return true;
      } else {
        _errorMessage =
            _extractMessage(response.body) ?? 'Cập nhật tuyến thất bại.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật tuyến: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> initRegisterRoute(String accessToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        KYCService.getRouteOptions(accessToken),
        KYCService.getRoutes(accessToken),
      ]);

      final routeOptionsResponse = results[0];
      final routesResponse = results[1];

      if (routeOptionsResponse.statusCode >= 200 &&
          routeOptionsResponse.statusCode < 300) {
        final List<dynamic> optionsData = jsonDecode(routeOptionsResponse.body);
        _routeOptions = optionsData
            .map((e) => RouteOptionModel.fromJson(e))
            .toList();
      } else {
        _errorMessage = _extractMessage(routeOptionsResponse.body) ??
            'Không thể tải route options.';
        return false;
      }

      if (routesResponse.statusCode >= 200 && routesResponse.statusCode < 300) {
        final Map<String, dynamic> routesData =
        jsonDecode(routesResponse.body);

        _routesData = RegisterRoutesResponseModel.fromJson(routesData);

        _selectedProvinceIds
          ..clear()
          ..addAll(
            _routesData!.selectedProvinces.map((e) => e.provinceId),
          );
      } else {
        _errorMessage = _extractMessage(routesResponse.body) ??
            'Không thể tải routes.';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khởi tạo đăng ký tuyến: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null) {
          return decoded['message'].toString();
        }
        if (decoded['error'] != null) {
          return decoded['error'].toString();
        }
        if (decoded['title'] != null) {
          return decoded['title'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  void reset() {
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    _routeOptions = [];
    _routesData = null;
    _selectedProvinceIds.clear();
    notifyListeners();
  }
}