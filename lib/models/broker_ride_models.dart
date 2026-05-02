import 'dart:convert';
//Model api tạo đơn bắn cho tài xế
/// ===============================
/// API #23 - Create Broker Ride
/// POST /api/rideapi/create-broker
/// ===============================

class BrokerRideTypeOption {
  final int value;
  final String label;

  const BrokerRideTypeOption({required this.value, required this.label});
}

class BrokerRideType {
  static const int passenger = 1;
  static const int charter5Seats = 2;
  static const int charter7Seats = 3;

  static const List<BrokerRideTypeOption> options = [
    BrokerRideTypeOption(value: passenger, label: 'Chở người'),
    BrokerRideTypeOption(value: charter5Seats, label: 'Bao xe 5 chỗ'),
    BrokerRideTypeOption(value: charter7Seats, label: 'Bao xe 7 chỗ'),
  ];

  static bool isValid(int type) {
    return type == passenger || type == charter5Seats || type == charter7Seats;
  }

  static bool requiresPassengerQuantity(int type) => type == passenger;

  static bool isCharter(int type) =>
      type == charter5Seats || type == charter7Seats;

  static int normalizeQuantity({required int type, required int quantity}) {
    if (isCharter(type)) return 1;
    return quantity;
  }

  static String labelOf(int type) {
    for (final option in options) {
      if (option.value == type) return option.label;
    }
    return 'Không xác định';
  }
}

class CreateBrokerRideRequest {
  final int fromDistrictId;
  final int toDistrictId;
  final String fromAddress;
  final String toAddress;
  final int type;
  final String customerPhone;
  final int quantity;

  final String pickupTime;

  final num offerPrice;
  final num creatorEarn;
  final String note;
  final int? groupId;

  const CreateBrokerRideRequest({
    required this.fromDistrictId,
    required this.toDistrictId,
    required this.fromAddress,
    required this.toAddress,
    required this.type,
    required this.customerPhone,
    required this.quantity,
    required this.pickupTime,
    required this.offerPrice,
    required this.creatorEarn,
    this.note = "",
    this.groupId,
  });

  int get normalizedQuantity =>
      BrokerRideType.normalizeQuantity(type: type, quantity: quantity);

  Map<String, dynamic> toJson() => {
    "fromDistrictId": fromDistrictId,
    "toDistrictId": toDistrictId,
    "fromAddress": fromAddress,
    "toAddress": toAddress,
    "type": type,
    "customerPhone": customerPhone,
    "quantity": normalizedQuantity,
    "pickupTime": pickupTime,
    "offerPrice": offerPrice,
    "creatorEarn": creatorEarn,
    "note": note,
    if (groupId != null) "groupId": groupId,
  };

  String toRawJson() => jsonEncode(toJson());

  /// Optional: validate nhẹ phía client để tránh gọi API vô ích
  /// (Backend vẫn là nguồn xác thực chính)
  void validate() {
    if (fromDistrictId <= 0) throw ArgumentError("fromDistrictId không hợp lệ");
    if (toDistrictId <= 0) throw ArgumentError("toDistrictId không hợp lệ");
    if (fromAddress.trim().isEmpty) throw ArgumentError("fromAddress rỗng");
    if (toAddress.trim().isEmpty) throw ArgumentError("toAddress rỗng");
    if (!BrokerRideType.isValid(type)) throw ArgumentError("type không hợp lệ");
    if (customerPhone.trim().isEmpty) throw ArgumentError("customerPhone rỗng");
    if (normalizedQuantity <= 0) throw ArgumentError("quantity phải > 0");
    if (offerPrice <= 0) throw ArgumentError("offerPrice phải > 0");
    if (creatorEarn <= 0) throw ArgumentError("creatorEarn phải > 0");
  }
}

class CreateBrokerRideResponse {
  final bool success;
  final CreateBrokerRideData? data;

  const CreateBrokerRideResponse({required this.success, required this.data});

  factory CreateBrokerRideResponse.fromJson(Map<String, dynamic> json) {
    return CreateBrokerRideResponse(
      success: json["success"] == true,
      data: json["data"] == null
          ? null
          : CreateBrokerRideData.fromJson(json["data"] as Map<String, dynamic>),
    );
  }

  factory CreateBrokerRideResponse.fromRawJson(String raw) =>
      CreateBrokerRideResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
}

class CreateBrokerRideData {
  final int id;
  final String code;
  final DateTime pickupTime;
  final num price;

  const CreateBrokerRideData({
    required this.id,
    required this.code,
    required this.pickupTime,
    required this.price,
  });

  factory CreateBrokerRideData.fromJson(Map<String, dynamic> json) {
    return CreateBrokerRideData(
      id: (json["id"] as num).toInt(),
      code: (json["code"] ?? "").toString(),
      pickupTime: DateTime.parse((json["pickupTime"] ?? "").toString()),
      price: (json["price"] as num),
    );
  }
}
