class WaitingRide {
  final int id;
  final int rideSource;
  final String? code;
  final String? createdAt;
  final String? fromPlaceId;
  final String? fromAddress;
  final String? fromDistrict;
  final String? fromProvince;
  final String? toPlaceId;
  final String? toAddress;
  final String? toDistrict;
  final String? toProvince;
  final String? pickupTime;
  final double price;
  final double netIncome;
  final int status;
  final int type;
  final int? quantity;
  final int paymentMethod;

  bool get hasQuantity => type == 1 && quantity != null;

  WaitingRide({
    required this.id,
    required this.rideSource,
    this.code,
    this.createdAt,
    this.fromPlaceId,
    this.fromAddress,
    this.fromProvince,
    this.toPlaceId,
    this.toAddress,
    this.toProvince,
    this.pickupTime,
    required this.price,
    required this.netIncome,
    required this.status,
    this.fromDistrict,
    this.toDistrict,
    required this.type,
    this.quantity,
    required this.paymentMethod,
  });

  factory WaitingRide.fromJson(Map<String, dynamic> json) {
    final from = _asMap(json['from']);
    final to = _asMap(json['to']);

    return WaitingRide(
      id: _parseInt(json['id']),
      rideSource: _parseInt(json['rideSource'], defaultValue: 1),
      code: json['code']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['createAt']?.toString(),
      fromPlaceId: _pickNullableString([json['fromPlaceId'], from?['placeId']]),
      fromAddress: _pickNullableString([
        json['fromFormattedAddress'],
        from?['formattedAddress'],
        json['fromAddress'],
      ]),
      fromProvince: _pickNullableString([
        json['fromProvinceName'],
        json['fromProvince'],
        from?['provinceName'],
      ]),
      toPlaceId: _pickNullableString([json['toPlaceId'], to?['placeId']]),
      toAddress: _pickNullableString([
        json['toFormattedAddress'],
        to?['formattedAddress'],
        json['toAddress'],
      ]),
      toProvince: _pickNullableString([
        json['toProvinceName'],
        json['toProvince'],
        to?['provinceName'],
      ]),
      pickupTime: json['pickupTime']?.toString(),
      price: _parseDouble(json['price']),
      netIncome: _parseDouble(json['netIncome'] ?? json['net_income']),
      status: _parseInt(json['status']),
      fromDistrict: _pickNullableString([
        json['fromDistrictName'],
        json['fromDistrict'],
        from?['districtName'],
      ]),
      toDistrict: _pickNullableString([
        json['toDistrictName'],
        json['toDistrict'],
        to?['districtName'],
      ]),
      type: _parseInt(json['type']),
      quantity: _parseNullableInt(json['quantity']),
      paymentMethod: _parseInt(json['paymentMethod'] ?? json['payment_method']),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  static String? _pickNullableString(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final raw = value.toString().trim();
      if (raw.isNotEmpty) return raw;
    }
    return null;
  }

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }
}
