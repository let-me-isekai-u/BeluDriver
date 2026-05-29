import '../broker_ride_models.dart';

class RideDetailModel {
  final int id;
  final String code;
  final int status;
  final double price;
  final double netIncome;
  final int type;
  final String paymentMethod;
  final String? pickupTime;
  final String? note;

  final String customerName;
  final String customerPhone;

  final String? fromPlaceId;
  final String fromAddress;
  final String fromProvince;
  final String fromDistrict;

  final String? toPlaceId;
  final String toAddress;
  final String toProvince;
  final String toDistrict;

  final String createdAt;
  final int quantity;

  RideDetailModel({
    required this.id,
    required this.code,
    required this.status,
    required this.price,
    required this.netIncome,
    required this.type,
    required this.paymentMethod,
    this.pickupTime,
    this.note,
    required this.customerName,
    required this.customerPhone,
    required this.fromPlaceId,
    required this.fromAddress,
    required this.fromProvince,
    required this.fromDistrict,
    required this.toPlaceId,
    required this.toAddress,
    required this.toProvince,
    required this.toDistrict,
    required this.createdAt,
    required this.quantity,
  });

  factory RideDetailModel.fromJson(Map<String, dynamic> json) {
    String pickCustomerName() {
      // Ver2 (rideSource=2) có thể trả tên ở key khác nhau so với Ver1.
      // Ưu tiên customerNameV2 trước, sau đó fallback sang V1, rồi tới customerName.
      final candidates = <String?>[
        json['customerNameV2']?.toString(),
        json['customer_name_v2']?.toString(),
        json['customerNameV1']?.toString(),
        json['customer_name_v1']?.toString(),
        json['customerName']?.toString(),
        json['customer_name']?.toString(),
      ];
      for (final v in candidates) {
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return 'Khách hàng';
    }

    String pickCustomerPhone() {
      final candidates = <String?>[
        json['customerPhoneV2']?.toString(),
        json['customer_phone_v2']?.toString(),
        json['customerPhoneV1']?.toString(),
        json['customer_phone_v1']?.toString(),
        json['customerPhone']?.toString(),
        json['customer_number']?.toString(),
        json['customerNumber']?.toString(),
      ].whereType<String>();

      for (final v in candidates) {
        final trimmed = v.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return '';
    }

    final from = _asMap(json['from']);
    final to = _asMap(json['to']);

    return RideDetailModel(
      id: _parseInt(json['id']),
      code: (json['code'] ?? '').toString(),
      status: _parseInt(json['status']),
      price: _parseDouble(json['price']),
      netIncome: _parseDouble(json['netIncome'] ?? json['net_income']),
      type: _parseInt(json['type'], defaultValue: 1),
      paymentMethod:
          (json['paymentMethodText'] ?? json['paymentMethod'] ?? 'Tiền mặt')
              .toString(),
      pickupTime: json['pickupTime']?.toString(),
      note: json['note']?.toString(),
      customerName: pickCustomerName(),
      customerPhone: pickCustomerPhone(),
      fromPlaceId: _pickNullableString([json['fromPlaceId'], from?['placeId']]),
      fromAddress: _pickString([
        json['fromFormattedAddress'],
        from?['formattedAddress'],
        json['fromAddress'],
      ]),
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
      toPlaceId: _pickNullableString([json['toPlaceId'], to?['placeId']]),
      toAddress: _pickString([
        json['toFormattedAddress'],
        to?['formattedAddress'],
        json['toAddress'],
      ]),
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
      createdAt: (json['createdAt'] ?? '').toString(),
      quantity: _parseInt(json['quantity'], defaultValue: 1),
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

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  String get typeText {
    return BrokerRideType.labelOf(type);
  }
}
