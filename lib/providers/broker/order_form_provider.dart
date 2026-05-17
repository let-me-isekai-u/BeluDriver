//provider sử dụng cho chức năng bắn đơn của tài xế
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/broker_ride_models.dart';
import '../../services/api_service.dart';

class OrderFormProvider extends ChangeNotifier {
  static const int hanoiProvinceId = 1;
  static const int noiBaiDistrictId = 974;
  static const String noiBaiAirportAddress = "Cảng hàng không quốc tế Nội Bài";

  final phoneController = TextEditingController();
  final customerNameController = TextEditingController();
  final noteController = TextEditingController();
  final quantityController = TextEditingController(text: "1");
  final fromAddressController = TextEditingController();
  final toAddressController = TextEditingController();
  final offerPriceController = TextEditingController();
  final creatorEarnController = TextEditingController();

  int selectedType = BrokerRideType.passenger;
  String lastPassengerQuantity = "1";

  int? fromProvinceId;
  int? fromDistrictId;
  int? toProvinceId;
  int? toDistrictId;

  DateTime? pickupDate;
  TimeOfDay? pickupTime;

  bool loadingProvinces = false;
  bool loadingFromDistricts = false;
  bool loadingToDistricts = false;

  List<dynamic> provinces = [];
  List<dynamic> fromDistricts = [];
  List<dynamic> toDistricts = [];

  List<dynamic> get availableFromDistricts => filterDistrictsForSelection(
    districts: fromDistricts,
    currentProvinceId: fromProvinceId,
    otherProvinceId: toProvinceId,
    otherDistrictId: toDistrictId,
  );

  List<dynamic> get availableToDistricts => filterDistrictsForSelection(
    districts: toDistricts,
    currentProvinceId: toProvinceId,
    otherProvinceId: fromProvinceId,
    otherDistrictId: fromDistrictId,
  );

  bool get requiresPassengerQuantity =>
      BrokerRideType.requiresPassengerQuantity(selectedType);

  bool get isCharterRide => BrokerRideType.isCharter(selectedType);

  int get normalizedQuantity {
    final rawQuantity = tryParseInt(quantityController.text) ?? 1;
    return BrokerRideType.normalizeQuantity(
      type: selectedType,
      quantity: rawQuantity,
    );
  }

  int? tryParseInt(String raw) => int.tryParse(raw.trim());
  num? tryParseNum(String raw) => num.tryParse(raw.trim());

  String formatDate(DateTime? date) =>
      date == null ? "" : DateFormat('dd/MM/yyyy').format(date);

  String formatTime(TimeOfDay? t) => t == null
      ? ""
      : "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  String? buildPickupIso() {
    if (pickupDate == null || pickupTime == null) return null;
    final dt = DateTime(
      pickupDate!.year,
      pickupDate!.month,
      pickupDate!.day,
      pickupTime!.hour,
      pickupTime!.minute,
    );
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
  }

  String getNameById(List<dynamic> items, int? id) {
    if (id == null) return '';
    final found = items.cast<dynamic>().firstWhere(
      (e) => e != null && e['id'].toString() == id.toString(),
      orElse: () => null,
    );
    return found?['name']?.toString() ?? '';
  }

  Future<void> loadProvinces() async {
    loadingProvinces = true;
    notifyListeners();
    try {
      provinces = await ApiService.getProvinces();
    } finally {
      loadingProvinces = false;
      notifyListeners();
    }
  }

  Future<void> loadDistrictsForFromProvince(int provinceId) async {
    syncAddressWithDistrict(isFrom: true, districtId: null);
    loadingFromDistricts = true;
    fromDistricts = [];
    fromDistrictId = null;
    notifyListeners();

    try {
      fromDistricts = await ApiService.getDistricts(provinceId: provinceId);
      _normalizeSelectedDistricts();
    } finally {
      loadingFromDistricts = false;
      notifyListeners();
    }
  }

  Future<void> loadDistrictsForToProvince(int provinceId) async {
    syncAddressWithDistrict(isFrom: false, districtId: null);
    loadingToDistricts = true;
    toDistricts = [];
    toDistrictId = null;
    notifyListeners();

    try {
      toDistricts = await ApiService.getDistricts(provinceId: provinceId);
      _normalizeSelectedDistricts();
    } finally {
      loadingToDistricts = false;
      notifyListeners();
    }
  }

  void updateRideType(int? nextType) {
    if (nextType == null || nextType == selectedType) return;

    if (requiresPassengerQuantity) {
      lastPassengerQuantity = quantityController.text.trim().isEmpty
          ? "1"
          : quantityController.text.trim();
    }

    selectedType = nextType;

    if (isCharterRide) {
      quantityController.text = "1";
    } else {
      quantityController.text = lastPassengerQuantity;
    }

    notifyListeners();
  }

  bool canSelectSameProvince(int? provinceId) {
    return provinceId == hanoiProvinceId;
  }

  List<dynamic> filterDistrictsForSelection({
    required List<dynamic> districts,
    required int? currentProvinceId,
    required int? otherProvinceId,
    required int? otherDistrictId,
  }) {
    if (currentProvinceId != hanoiProvinceId ||
        otherProvinceId != hanoiProvinceId) {
      return districts;
    }

    if (otherDistrictId == null) {
      return districts;
    }

    if (otherDistrictId == noiBaiDistrictId) {
      return districts.where((district) {
        final id = parseLocationId(district['id']);
        return id != noiBaiDistrictId;
      }).toList();
    }

    return districts.where((district) {
      final id = parseLocationId(district['id']);
      return id == noiBaiDistrictId;
    }).toList();
  }

  bool _containsDistrictId(List<dynamic> districts, int? districtId) {
    if (districtId == null) return true;
    return districts.any((district) {
      final id = parseLocationId(district['id']);
      return id == districtId;
    });
  }

  void _normalizeSelectedDistricts() {
    if (!_containsDistrictId(availableFromDistricts, fromDistrictId)) {
      fromDistrictId = null;
      syncAddressWithDistrict(isFrom: true, districtId: null);
    }

    if (!_containsDistrictId(availableToDistricts, toDistrictId)) {
      toDistrictId = null;
      syncAddressWithDistrict(isFrom: false, districtId: null);
    }
  }

  int? parseLocationId(dynamic rawId) {
    if (rawId is int) return rawId;
    return int.tryParse(rawId.toString());
  }

  void syncAddressWithDistrict({
    required bool isFrom,
    required int? districtId,
  }) {
    final controller = isFrom ? fromAddressController : toAddressController;

    if (districtId == noiBaiDistrictId) {
      controller.text = noiBaiAirportAddress;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      notifyListeners();
      return;
    }

    if (controller.text.trim() == noiBaiAirportAddress) {
      controller.clear();
      notifyListeners();
    }
  }

  void setFromProvince(int? value) {
    fromProvinceId = value;
    _normalizeSelectedDistricts();
    notifyListeners();
  }

  void setFromDistrict(int? value) {
    fromDistrictId = value;
    _normalizeSelectedDistricts();
    notifyListeners();
  }

  void setToProvince(int? value) {
    toProvinceId = value;
    _normalizeSelectedDistricts();
    notifyListeners();
  }

  void setToDistrict(int? value) {
    toDistrictId = value;
    _normalizeSelectedDistricts();
    notifyListeners();
  }

  void setPickupDate(DateTime? value) {
    pickupDate = value;
    notifyListeners();
  }

  void setPickupTime(TimeOfDay? value) {
    pickupTime = value;
    notifyListeners();
  }

  String? validate() {
    if (customerNameController.text.trim().isEmpty) {
      return "Vui lòng nhập tên khách";
    }

    if (phoneController.text.trim().isEmpty) {
      return "Vui lòng nhập số điện thoại khách";
    }

    if (requiresPassengerQuantity) {
      final q = tryParseInt(quantityController.text);
      if (q == null || q < 1) {
        return "Số lượng phải là số nguyên ≥ 1";
      }
    }

    if (fromProvinceId == null ||
        fromDistrictId == null ||
        fromAddressController.text.trim().isEmpty) {
      return "Vui lòng nhập đầy đủ điểm đón";
    }

    if (toProvinceId == null ||
        toDistrictId == null ||
        toAddressController.text.trim().isEmpty) {
      return "Vui lòng nhập đầy đủ điểm đến";
    }

    final pickupIso = buildPickupIso();
    if (pickupIso == null) {
      return "Vui lòng chọn ngày & giờ đón";
    }

    final offer = tryParseNum(offerPriceController.text);
    if (offer == null || offer <= 0) {
      return "Vui lòng nhập giá chào hợp lệ";
    }

    final earn = tryParseNum(creatorEarnController.text);
    if (earn == null || earn <= 0) {
      return "Vui lòng nhập tiền nhận hợp lệ";
    }

    if (earn > offer) {
      return "Tiền nhận không được lớn hơn giá chào";
    }

    return null;
  }

  CreateBrokerRideRequest buildRequest({int? groupId}) {
    return CreateBrokerRideRequest(
      fromDistrictId: fromDistrictId!,
      toDistrictId: toDistrictId!,
      fromAddress: fromAddressController.text.trim(),
      toAddress: toAddressController.text.trim(),
      type: selectedType,
      customerName: customerNameController.text.trim(),
      customerPhone: phoneController.text.trim(),
      quantity: normalizedQuantity,
      pickupTime: buildPickupIso()!,
      offerPrice: num.parse(offerPriceController.text.trim()),
      creatorEarn: num.parse(creatorEarnController.text.trim()),
      note: noteController.text.trim(),
      groupId: groupId,
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    customerNameController.dispose();
    noteController.dispose();
    quantityController.dispose();
    fromAddressController.dispose();
    toAddressController.dispose();
    offerPriceController.dispose();
    creatorEarnController.dispose();
    super.dispose();
  }
}
