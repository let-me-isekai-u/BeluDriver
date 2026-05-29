//Model dùng cho API 24
import 'dart:convert';

import '../broker_ride_models.dart';

class BrokerRidesResponse {
  final bool success;
  final List<BrokerRideItem> data;

  const BrokerRidesResponse({required this.success, required this.data});

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

  final String? fromPlaceId;
  final String fromProvince;
  final String fromDistrict;
  final String fromAddress;

  final String? toPlaceId;
  final String toProvince;
  final String toDistrict;
  final String toAddress;

  final num price;
  final int status;
  final String paymentMethod;
  final int type;
  final int? quantity;

  const BrokerRideItem({
    required this.rideId,
    required this.code,
    required this.createdAt,
    required this.pickupTime,
    required this.fromPlaceId,
    required this.fromProvince,
    required this.fromDistrict,
    required this.fromAddress,
    required this.toPlaceId,
    required this.toProvince,
    required this.toDistrict,
    required this.toAddress,
    required this.price,
    required this.status,
    required this.paymentMethod,
    required this.type,
    required this.quantity,
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
    final from = _asMap(json['from']);
    final to = _asMap(json['to']);

    return BrokerRideItem(
      rideId: int.tryParse(json['rideId']?.toString() ?? '0') ?? 0,
      code: (json['code'] ?? '').toString(),
      createdAt: _parseDateTime(json['createdAt']?.toString()),
      pickupTime: _parseNullableDateTime(json['pickupTime']?.toString()),
      fromPlaceId: _pickNullableString([json['fromPlaceId'], from?['placeId']]),
      fromProvince: _pickString([
        json['fromProvinceName'],
        json['fromProvince'],
        from?['provinceName'],
      ]),
      fromDistrict: _pickString([
        json['fromDistrictName'],
        json['fromDistrict'],
        from?['districtName'],
      ]),
      fromAddress: _pickString([
        json['fromFormattedAddress'],
        from?['formattedAddress'],
        json['fromAddress'],
      ]),
      toPlaceId: _pickNullableString([json['toPlaceId'], to?['placeId']]),
      toProvince: _pickString([
        json['toProvinceName'],
        json['toProvince'],
        to?['provinceName'],
      ]),
      toDistrict: _pickString([
        json['toDistrictName'],
        json['toDistrict'],
        to?['districtName'],
      ]),
      toAddress: _pickString([
        json['toFormattedAddress'],
        to?['formattedAddress'],
        json['toAddress'],
      ]),
      price: (json['price'] as num?) ?? 0,
      status: int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      type: int.tryParse(json['type']?.toString() ?? '1') ?? 1,
      quantity: int.tryParse(json['quantity']?.toString() ?? ''),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  static String _pickString(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      if (value == null) continue;
      final raw = value.toString().trim();
      if (raw.isNotEmpty) return raw;
    }
    return fallback;
  }

  static String? _pickNullableString(List<dynamic> values) {
    final value = _pickString(values);
    return value.isEmpty ? null : value;
  }

  String get rideTypeOrQuantityText {
    return BrokerRideType.summaryOf(type, quantity);
  }
}
