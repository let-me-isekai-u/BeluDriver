import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../models/paged_response_model.dart';
import '../models/waiting_ride_model.dart';
import '../models/driver/broker_rides_model.dart';
import '../services/api_service.dart';

class RecieveOrderProvider extends ChangeNotifier {
  static const int pageSize = 20;

  final PagingController<int, WaitingRide> pagingController =
  PagingController(firstPageKey: 1);

  List<dynamic> provinces = [];
  int? selectedProvinceId;

  List<dynamic> districts = [];
  int? selectedDistrictId;

  List<Map<String, dynamic>> acceptedRides = [];
  bool isLoadingAcceptedRides = false;
  bool isAcceptedLoaded = false;

  final Set<int> myBrokerRideIds = <int>{};
  bool loadingMyBrokerRides = false;

  RecieveOrderProvider() {
    pagingController.addPageRequestListener((pageKey) {
      fetchNewRidesPage(pageKey);
    });
  }

  @override
  void dispose() {
    pagingController.dispose();
    super.dispose();
  }

  Future<void> init() async {
    await Future.wait([
      loadProvinces(),
      loadMyBrokerRideIds(),
    ]);
  }

  void applyFilter() {
    pagingController.refresh();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? '';
  }

  // ====================== Ride source helpers ======================

  String rideSourceText(int rideSource) {
    switch (rideSource) {
      case 1:
        return "Đơn BeluCar";
      case 2:
        return "Đơn cộng đồng";
      default:
        return "Không xác định";
    }
  }

  int extractRideSource(dynamic ride) {
    if (ride is WaitingRide) return ride.rideSource;
    if (ride is Map) {
      return int.tryParse(
        ride['rideSource']?.toString() ??
            ride['ride_source']?.toString() ??
            '1',
      ) ??
          1;
    }
    return 1;
  }

  int extractRideId(dynamic ride) {
    if (ride is WaitingRide) return ride.id;
    return int.tryParse(
      ride['rideId']?.toString() ?? ride['id']?.toString() ?? '0',
    ) ??
        0;
  }

  bool isMyBrokerRide(dynamic ride) {
    final int rideId = extractRideId(ride);
    if (rideId == 0) return false;
    return myBrokerRideIds.contains(rideId);
  }

  // ====================== API & paging ======================

  Future<void> fetchNewRidesPage(int pageKey) async {
    try {
      final token = await _getToken();

      if (selectedDistrictId != null) {
        final res = await ApiService.searchRideByFromDistrict(
          accessToken: token,
          fromDistrictId: selectedDistrictId!,
        );

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true) {
            final List<dynamic> list = body['data'] ?? [];
            final items = list
                .map<WaitingRide>(
                  (json) => WaitingRide.fromJson(json as Map<String, dynamic>),
            )
                .toList();

            pagingController.appendLastPage(items);
            return;
          } else {
            pagingController.error = "Không thể tải dữ liệu (filter theo huyện)";
            return;
          }
        } else {
          pagingController.error =
          "Không thể tải dữ liệu từ máy chủ (filter theo huyện)";
          return;
        }
      }

      final res = await ApiService.getWaitingRidesPaged(
        accessToken: token,
        page: pageKey,
        pageSize: pageSize,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final dynamic pagedData = body['data'] ?? body;

        final pagedResponse = PagedResponse<WaitingRide>.fromJson(
          pagedData,
              (json) => WaitingRide.fromJson(json as Map<String, dynamic>),
        );

        final newItems = pagedResponse.data;

        if (!pagedResponse.hasNext) {
          pagingController.appendLastPage(newItems);
        } else {
          final nextPageKey = pageKey + 1;
          pagingController.appendPage(newItems, nextPageKey);
        }
      } else {
        pagingController.error = "Không thể tải dữ liệu từ máy chủ";
      }
    } catch (e) {
      debugPrint("Lỗi phân trang: $e");
      pagingController.error = e;
    }
  }

  Future<void> loadMyBrokerRideIds() async {
    loadingMyBrokerRides = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token.isEmpty) return;

      final res = await ApiService.getBrokerRides(accessToken: token);
      if (res.statusCode == 200) {
        final parsed = BrokerRidesResponse.fromRawJson(res.body);
        if (parsed.success) {
          final ids = parsed.data.map((e) => e.rideId).toSet();
          myBrokerRideIds
            ..clear()
            ..addAll(ids);
          notifyListeners();
        }
      } else {
        debugPrint("getBrokerRides() status=${res.statusCode} body=${res.body}");
      }
    } catch (e) {
      debugPrint("Lỗi load broker rides: $e");
    } finally {
      loadingMyBrokerRides = false;
      notifyListeners();
    }
  }

  Future<void> loadProvinces() async {
    try {
      final token = await _getToken();

      final res = await ApiService.getRideCountByProvince(accessToken: token);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'] ?? [];
          provinces = data;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Lỗi load provinces: $e");
    }
  }

  Future<void> loadAcceptedRides() async {
    isLoadingAcceptedRides = true;
    notifyListeners();

    try {
      final token = await _getToken();

      final res = await ApiService.getAcceptedRides(accessToken: token);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> ridesData = body['data'] ?? [];
          acceptedRides = ridesData
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
          isAcceptedLoaded = true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Lỗi load accepted rides: $e");
    } finally {
      isLoadingAcceptedRides = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> acceptRide(WaitingRide ride) async {
    final token = await _getToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'Token không hợp lệ',
      };
    }

    final res = await ApiService.acceptRide(
      accessToken: token,
      id: ride.id,
      rideSource: ride.rideSource,
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);

      final currentItems = pagingController.itemList ?? [];
      currentItems.removeWhere((item) => item.id == ride.id);
      pagingController.itemList = List.from(currentItems);

      isAcceptedLoaded = false;
      notifyListeners();

      return {
        'success': true,
        'message': body['message'] ?? "Nhận đơn thành công",
      };
    } else {
      pagingController.refresh();
      return {
        'success': false,
        'message': "Đơn đã được nhận bởi tài xế khác!",
      };
    }
  }

  Future<Map<String, dynamic>> cancelMyBrokerRide(dynamic ride) async {
    final int rideId = extractRideId(ride);
    if (rideId == 0) {
      return {
        'success': false,
        'message': 'Ride không hợp lệ',
      };
    }

    final token = await _getToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'Token không hợp lệ',
      };
    }

    final res =
    await ApiService.cancelBrokerRide(accessToken: token, rideId: rideId);

    if (res.statusCode == 200) {
      myBrokerRideIds.remove(rideId);
      notifyListeners();

      pagingController.refresh();
      await loadMyBrokerRideIds();

      return {
        'success': true,
        'message': 'Huỷ đơn thành công',
      };
    } else {
      return {
        'success': false,
        'message': 'Huỷ đơn thất bại (${res.statusCode})',
      };
    }
  }

  Future<Map<String, dynamic>> startRide(dynamic ride) async {
    final token = await _getToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'Token không hợp lệ',
      };
    }

    final int rideId = extractRideId(ride);
    if (rideId == 0) {
      return {
        'success': false,
        'message': 'Ride không hợp lệ',
      };
    }

    final int rideSource = extractRideSource(ride);

    final res = await ApiService.startRide(
      accessToken: token,
      rideId: rideId,
      rideSource: rideSource,
    );

    if (res.statusCode == 200) {
      return {
        'success': true,
        'message': 'Bắt đầu chuyến đi thành công',
        'rideId': rideId,
        'rideSource': rideSource,
      };
    }

    return {
      'success': false,
      'message': 'Không thể bắt đầu chuyến đi',
    };
  }

  List<Map<String, dynamic>> get acceptedRidesStatus2 {
    return acceptedRides
        .where((ride) => (int.tryParse(ride['status'].toString()) ?? 0) == 2)
        .toList();
  }

  // ====================== Helpers ======================

  String extractProvinceFromMap(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
    }
    return '';
  }

  dynamic extractDynamicFromMap(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final v = m[k];
        if (v != null) return v;
      }
    }
    return null;
  }

  String formatPickupTime(dynamic value) {
    if (value == null) return '';
    try {
      if (value is int) {
        final int v = value;
        final int ms = v.abs() > 1000000000000 ? v : v * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms)
            .toLocal()
            .toString();
      }

      final s = value.toString().trim();
      if (s.isEmpty) return '';

      if (RegExp(r'^\d+$').hasMatch(s)) {
        final int v = int.parse(s);
        final int ms = v.abs() > 1000000000000 ? v : v * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms)
            .toLocal()
            .toString();
      }

      final DateTime dt = DateTime.parse(s);
      return dt.toLocal().toString();
    } catch (_) {
      return value.toString();
    }
  }

  String buildFullAddress(String? address, String? district, String? province) {
    final a = (address ?? '').trim();
    final d = (district ?? '').trim();
    final p = (province ?? '').trim();

    final parts = <String>[];
    if (a.isNotEmpty) parts.add(a);
    if (d.isNotEmpty) parts.add(d);
    if (p.isNotEmpty) parts.add(p);

    return parts.join(', ');
  }
}