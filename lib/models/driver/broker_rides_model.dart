import 'dart:convert';
//model api 24
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

  /// Có thể là "0001-01-01T00:00:00" => coi như null
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
    // backend dùng "0001-01-01T00:00:00" như giá trị rỗng
    if (raw.startsWith('0001-01-01')) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  factory BrokerRideItem.fromJson(Map<String, dynamic> json) {
    return BrokerRideItem(
      rideId: (json['rideId'] as num).toInt(),
      code: (json['code'] ?? '').toString(),
      createdAt: DateTime.parse((json['createdAt'] ?? '').toString()),
      pickupTime: _parseNullableDateTime(json['pickupTime']?.toString()),
      fromProvince: (json['fromProvince'] ?? '').toString(),
      fromDistrict: (json['fromDistrict'] ?? '').toString(),
      fromAddress: (json['fromAddress'] ?? '').toString(),
      toProvince: (json['toProvince'] ?? '').toString(),
      toDistrict: (json['toDistrict'] ?? '').toString(),
      toAddress: (json['toAddress'] ?? '').toString(),
      price: (json['price'] as num?) ?? 0,
      status: (json['status'] as num?)?.toInt() ?? 0,
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
    );
  }
}