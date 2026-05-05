import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/paged_response_model.dart';
import '../models/waiting_ride_model.dart';
import '../models/driver/broker_rides_model.dart';
import '../services/api_service.dart';

enum WaitingRideSortOption { createdAtDesc, pickupTimeAsc }

abstract class WaitingRideListItem {
  const WaitingRideListItem();
}

class WaitingRideDateHeaderItem extends WaitingRideListItem {
  const WaitingRideDateHeaderItem(this.date);

  final DateTime? date;
}

class WaitingRideCardItem extends WaitingRideListItem {
  const WaitingRideCardItem(this.ride);

  final WaitingRide ride;
}

class RecieveOrderProvider extends ChangeNotifier {
  static const int pageSize = 20;

  final PagingController<int, WaitingRideListItem> pagingController =
      PagingController(firstPageKey: 1);

  final List<WaitingRide> _waitingRides = <WaitingRide>[];
  WaitingRideSortOption _sortOption = WaitingRideSortOption.createdAtDesc;

  List<dynamic> provinces = [];
  int? selectedProvinceId;

  List<dynamic> districts = [];
  int? selectedDistrictId;

  List<Map<String, dynamic>> acceptedRides = [];
  bool isLoadingAcceptedRides = false;
  bool isAcceptedLoaded = false;

  final Set<int> myBrokerRideIds = <int>{};
  bool loadingMyBrokerRides = false;

  WaitingRideSortOption get sortOption => _sortOption;

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
    await Future.wait([loadProvinces(), loadMyBrokerRideIds()]);
  }

  void applyFilter() {
    _waitingRides.clear();
    pagingController.refresh();
  }

  void setSortOption(WaitingRideSortOption value) {
    if (_sortOption == value) return;
    _sortOption = value;
    _rebuildWaitingRideItems();
    notifyListeners();
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
      if (pageKey == pagingController.firstPageKey) {
        _waitingRides.clear();
      }

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

            _setWaitingRidePage(
              items,
              nextPageKey: null,
              replaceExisting: true,
            );
            return;
          } else {
            pagingController.error =
                "Không thể tải dữ liệu (filter theo huyện)";
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

        _setWaitingRidePage(
          newItems,
          nextPageKey: pagedResponse.hasNext ? pageKey + 1 : null,
          replaceExisting: pageKey == pagingController.firstPageKey,
        );
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
        debugPrint(
          "getBrokerRides() status=${res.statusCode} body=${res.body}",
        );
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
      return {'success': false, 'message': 'Token không hợp lệ'};
    }

    final res = await ApiService.acceptRide(
      accessToken: token,
      id: ride.id,
      rideSource: ride.rideSource,
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);

      _waitingRides.removeWhere(
        (item) => item.id == ride.id && item.rideSource == ride.rideSource,
      );
      _rebuildWaitingRideItems();

      isAcceptedLoaded = false;
      notifyListeners();

      return {
        'success': true,
        'message': body['message'] ?? "Nhận đơn thành công",
      };
    } else {
      pagingController.refresh();
      return {'success': false, 'message': "Đơn đã được nhận bởi tài xế khác!"};
    }
  }

  Future<Map<String, dynamic>> cancelMyBrokerRide(dynamic ride) async {
    final int rideId = extractRideId(ride);
    if (rideId == 0) {
      return {'success': false, 'message': 'Ride không hợp lệ'};
    }

    final token = await _getToken();
    if (token.isEmpty) {
      return {'success': false, 'message': 'Token không hợp lệ'};
    }

    final res = await ApiService.cancelBrokerRide(
      accessToken: token,
      rideId: rideId,
    );

    if (res.statusCode == 200) {
      myBrokerRideIds.remove(rideId);
      notifyListeners();

      pagingController.refresh();
      await loadMyBrokerRideIds();

      return {'success': true, 'message': 'Huỷ đơn thành công'};
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
      return {'success': false, 'message': 'Token không hợp lệ'};
    }

    final int rideId = extractRideId(ride);
    if (rideId == 0) {
      return {'success': false, 'message': 'Ride không hợp lệ'};
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

    return {'success': false, 'message': 'Không thể bắt đầu chuyến đi'};
  }

  List<Map<String, dynamic>> get acceptedRidesStatus2 {
    return acceptedRides
        .where((ride) => (int.tryParse(ride['status'].toString()) ?? 0) == 2)
        .toList();
  }

  String sortOptionLabel(WaitingRideSortOption option) {
    switch (option) {
      case WaitingRideSortOption.createdAtDesc:
        return 'Ngày đặt mới nhất';
      case WaitingRideSortOption.pickupTimeAsc:
        return 'Giờ đón sớm nhất';
    }
  }

  // ====================== Helpers ======================

  void _setWaitingRidePage(
    List<WaitingRide> newItems, {
    required int? nextPageKey,
    required bool replaceExisting,
  }) {
    if (replaceExisting) {
      _waitingRides
        ..clear()
        ..addAll(newItems);
    } else {
      final existingKeys = _waitingRides
          .map((ride) => '${ride.id}_${ride.rideSource}')
          .toSet();

      for (final ride in newItems) {
        final key = '${ride.id}_${ride.rideSource}';
        if (existingKeys.add(key)) {
          _waitingRides.add(ride);
        }
      }
    }

    _rebuildWaitingRideItems(nextPageKey: nextPageKey);
  }

  void _rebuildWaitingRideItems({int? nextPageKey}) {
    final sortedRides = List<WaitingRide>.from(_waitingRides)
      ..sort(_compareWaitingRides);

    final displayItems = <WaitingRideListItem>[];
    DateTime? currentHeaderDate;

    for (final ride in sortedRides) {
      if (_sortOption == WaitingRideSortOption.createdAtDesc) {
        final headerDate = _dateOnly(extractCreatedAt(ride));
        if (!_isSameDay(currentHeaderDate, headerDate)) {
          displayItems.add(WaitingRideDateHeaderItem(headerDate));
          currentHeaderDate = headerDate;
        }
      }

      displayItems.add(WaitingRideCardItem(ride));
    }

    pagingController.value = PagingState<int, WaitingRideListItem>(
      itemList: displayItems,
      error: null,
      nextPageKey: nextPageKey ?? pagingController.nextPageKey,
    );
  }

  int _compareWaitingRides(WaitingRide a, WaitingRide b) {
    switch (_sortOption) {
      case WaitingRideSortOption.createdAtDesc:
        final createdCompare = _compareDateDesc(
          extractCreatedAt(a),
          extractCreatedAt(b),
        );
        if (createdCompare != 0) return createdCompare;
        return _compareDateAsc(
          extractPickupDateTime(a),
          extractPickupDateTime(b),
        );
      case WaitingRideSortOption.pickupTimeAsc:
        final pickupCompare = _compareDateAsc(
          extractPickupDateTime(a),
          extractPickupDateTime(b),
        );
        if (pickupCompare != 0) return pickupCompare;
        return _compareDateDesc(extractCreatedAt(a), extractCreatedAt(b));
    }
  }

  int _compareDateDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  int _compareDateAsc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

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

  DateTime? extractCreatedAt(dynamic ride) {
    if (ride is WaitingRide) {
      return parseDateTime(ride.createdAt);
    }

    if (ride is Map) {
      return parseDateTime(
        extractDynamicFromMap(ride, [
          'createdAt',
          'created_at',
          'createAt',
          'create_at',
        ]),
      );
    }

    return null;
  }

  DateTime? extractPickupDateTime(dynamic ride) {
    if (ride is WaitingRide) {
      return parseDateTime(ride.pickupTime);
    }

    if (ride is Map) {
      return parseDateTime(
        extractDynamicFromMap(ride, [
          'pickupTime',
          'pickup_time',
          'pickupAt',
          'pickup_at',
          'pickuptime',
          'pickupDate',
          'pickup_date',
        ]),
      );
    }

    return null;
  }

  DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value.toLocal();

    try {
      if (value is int) {
        final ms = value.abs() > 1000000000000 ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      }

      final raw = value.toString().trim();
      if (raw.isEmpty || raw.startsWith('0001-01-01')) return null;

      if (RegExp(r'^\d+$').hasMatch(raw)) {
        final parsed = int.parse(raw);
        final ms = parsed.abs() > 1000000000000 ? parsed : parsed * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      }

      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  String formatCreatedDateHeader(DateTime? value) {
    if (value == null) return 'Không rõ ngày đặt';
    return DateFormat('dd/MM/yyyy').format(value.toLocal());
  }

  String formatPickupTime(dynamic value) {
    final parsed = parseDateTime(value);
    if (parsed == null) return value?.toString() ?? '';
    return parsed.toString();
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
