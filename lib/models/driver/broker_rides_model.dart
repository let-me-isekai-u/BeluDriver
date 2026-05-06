//Model dùng cho API 24
import 'dart:convert';

class BrokerRidesResponse {
  final bool success;
  final List<BrokerRideItem> data;

  const BrokerRidesResponse({
    required this.success,
    required this.data,
  });

  factory BrokerRidesResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'];
    return BrokerRidesResponse(
      success: json['success'] == true,
      data: rawList is List
          ? rawList
          .whereType<Map<String, dynamic>>()
          .map(BrokerRideItem.fromJson)
          .toList()
          : <BrokerRideItem>[],
    );
  }

  factory BrokerRidesResponse.fromRawJson(String raw) =>
      BrokerRidesResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class BrokerRideItem {
  final int rideId;
  final String code;
  final DateTime createdAt;
  final DateTime? pickupTime;

  final String fromProvince;
  final String fromDistrict;
  final String fromAddress;

  final String toProvince;
  final String toDistrict;
  final String toAddress;

  final num price;
  final int status;
  final String paymentMethod;

  const BrokerRideItem({
    required this.rideId,
    required this.code,
    required this.createdAt,
    required this.pickupTime,
    required this.fromProvince,
    required this.fromDistrict,
    required this.fromAddress,
    required this.toProvince,
    required this.toDistrict,
    required this.toAddress,
    required this.price,
    required this.status,
    required this.paymentMethod,
  });

  static DateTime? _parseNullableDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('0001-01-01')) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static DateTime _parseDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return DateTime.now();
    }
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.now();
    }
  }

  factory BrokerRideItem.fromJson(Map<String, dynamic> json) {
    return BrokerRideItem(
      rideId: int.tryParse(json['rideId']?.toString() ?? '0') ?? 0,
      code: (json['code'] ?? '').toString(),
      createdAt: _parseDateTime(json['createdAt']?.toString()),
      pickupTime: _parseNullableDateTime(json['pickupTime']?.toString()),
      fromProvince: (json['fromProvince'] ?? '').toString(),
      fromDistrict: (json['fromDistrict'] ?? '').toString(),
      fromAddress: (json['fromAddress'] ?? '').toString(),
      toProvince: (json['toProvince'] ?? '').toString(),
      toDistrict: (json['toDistrict'] ?? '').toString(),
      toAddress: (json['toAddress'] ?? '').toString(),
      price: (json['price'] as num?) ?? 0,
      status: int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
    );
  }
}