import 'dart:convert';

import 'location_models.dart';

// Model api tạo đơn bắn cho tài xế
/// ===============================
/// API #23 - Create Broker Ride
/// POST /api/v2/ride/create-broker
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
    return quantity < 1 ? 1 : quantity;
  }

  static String labelOf(int type) {
    for (final option in options) {
      if (option.value == type) return option.label;
    }
    return 'Không xác định';
  }

  static String quantityLabelOf(int type) {
    return requiresPassengerQuantity(type) ? 'Số lượng hành khách' : 'Số lượng';
  }

  static String summaryOf(int type, int? quantity) {
    if (type == passenger && quantity != null) {
      return '$quantity người';
    }
    return labelOf(type);
  }
}

class CreateBrokerRideRequest {
  final RidePointPayload from;
  final RidePointPayload to;
  final String fromDisplayAddress;
  final String toDisplayAddress;
  final int type;
  final String customerName;
  final String customerPhone;
  final int quantity;
  final String pickupTime;
  final num offerPrice;
  final num creatorEarn;
  final String note;
  final int? groupId;

  const CreateBrokerRideRequest({
    required this.from,
    required this.to,
    required this.fromDisplayAddress,
    required this.toDisplayAddress,
    required this.type,
    required this.customerName,
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
    "from": from.toJson(),
    "to": to.toJson(),
    "type": type,
    "customerName": customerName,
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
    if (!from.isValid) throw ArgumentError("from không hợp lệ");
    if (!to.isValid) throw ArgumentError("to không hợp lệ");
    if (!BrokerRideType.isValid(type)) throw ArgumentError("type không hợp lệ");
    if (customerName.trim().isEmpty) throw ArgumentError("customerName rỗng");
    if (customerPhone.trim().isEmpty) throw ArgumentError("customerPhone rỗng");
    if (normalizedQuantity <= 0) throw ArgumentError("quantity phải > 0");
    if (offerPrice <= 0) throw ArgumentError("offerPrice phải > 0");
    if (creatorEarn <= 0) throw ArgumentError("creatorEarn phải > 0");
  }
}

class CreateBrokerRideResponse {
  final String? message;
  final bool success;
  final CreateBrokerRideData? data;

  const CreateBrokerRideResponse({
    required this.success,
    required this.data,
    this.message,
  });

  factory CreateBrokerRideResponse.fromJson(Map<String, dynamic> json) {
    return CreateBrokerRideResponse(
      success: json["success"] == true,
      message: json["message"]?.toString(),
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
  final DateTime? pickupTime;
  final num price;
  final String paymentMethod;
  final int status;
  final String statusText;

  const CreateBrokerRideData({
    required this.id,
    required this.code,
    required this.pickupTime,
    required this.price,
    required this.paymentMethod,
    required this.status,
    required this.statusText,
  });

  factory CreateBrokerRideData.fromJson(Map<String, dynamic> json) {
    return CreateBrokerRideData(
      id: ((json["id"] as num?) ?? 0).toInt(),
      code: (json["code"] ?? "").toString(),
      pickupTime: DateTime.tryParse((json["pickupTime"] ?? "").toString()),
      price: (json["price"] as num?) ?? 0,
      paymentMethod: (json["paymentMethod"] ?? "").toString(),
      status: int.tryParse(json["status"]?.toString() ?? "0") ?? 0,
      statusText: (json["statusText"] ?? "").toString(),
    );
  }
}
