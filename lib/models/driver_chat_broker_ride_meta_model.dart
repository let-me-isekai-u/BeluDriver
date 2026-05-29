class DriverChatBrokerRideMetaModel {
  final int brokerRideId;
  final int? groupId;
  final String code;
  final int status;
  final int type;
  final int quantity;
  final DateTime? pickupTime;

  final String? fromPlaceId;
  final int? fromDistrictId;
  final String? fromDistrictName;
  final String fromAddress;

  final String? toPlaceId;
  final int? toDistrictId;
  final String? toDistrictName;
  final String toAddress;

  final String customerPhone;

  final double offerPrice;
  final double acceptedPrice;
  final double creatorEarn;
  final double systemCommissionPercent;

  final int paymentMethod;
  final String paymentMethodText;
  final String? note;

  final int? createdDriverId;
  final String? createdDriverName;
  final int? acceptedDriverId;
  final String? acceptedDriverName;

  DriverChatBrokerRideMetaModel({
    required this.brokerRideId,
    required this.groupId,
    required this.code,
    required this.status,
    required this.type,
    required this.quantity,
    required this.pickupTime,
    required this.fromPlaceId,
    required this.fromDistrictId,
    required this.fromDistrictName,
    required this.fromAddress,
    required this.toPlaceId,
    required this.toDistrictId,
    required this.toDistrictName,
    required this.toAddress,
    required this.customerPhone,
    required this.offerPrice,
    required this.acceptedPrice,
    required this.creatorEarn,
    required this.systemCommissionPercent,
    required this.paymentMethod,
    required this.paymentMethodText,
    required this.note,
    required this.createdDriverId,
    required this.createdDriverName,
    required this.acceptedDriverId,
    required this.acceptedDriverName,
  });

  factory DriverChatBrokerRideMetaModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      return null;
    }

    String? pickNullableString(List<dynamic> values) {
      for (final value in values) {
        if (value == null) continue;
        final raw = value.toString().trim();
        if (raw.isNotEmpty) return raw;
      }
      return null;
    }

    final from = asMap(json['from']);
    final to = asMap(json['to']);

    return DriverChatBrokerRideMetaModel(
      brokerRideId: parseInt(json['brokerRideId']),
      groupId: parseNullableInt(json['groupId']),
      code: json['code']?.toString() ?? '',
      status: parseInt(json['status']),
      type: parseInt(json['type']),
      quantity: parseInt(json['quantity']),
      pickupTime: json['pickupTime'] == null
          ? null
          : DateTime.tryParse(json['pickupTime'].toString()),
      fromPlaceId: pickNullableString([json['fromPlaceId'], from?['placeId']]),
      fromDistrictId: parseNullableInt(json['fromDistrictId']),
      fromDistrictName: pickNullableString([
        json['fromDistrictName'],
        json['fromDistrict'],
        from?['districtName'],
      ]),
      fromAddress:
          pickNullableString([
            json['fromFormattedAddress'],
            from?['formattedAddress'],
            json['fromAddress'],
          ]) ??
          '',
      toPlaceId: pickNullableString([json['toPlaceId'], to?['placeId']]),
      toDistrictId: parseNullableInt(json['toDistrictId']),
      toDistrictName: pickNullableString([
        json['toDistrictName'],
        json['toDistrict'],
        to?['districtName'],
      ]),
      toAddress:
          pickNullableString([
            json['toFormattedAddress'],
            to?['formattedAddress'],
            json['toAddress'],
          ]) ??
          '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      offerPrice: parseDouble(json['offerPrice']),
      acceptedPrice: parseDouble(json['acceptedPrice']),
      creatorEarn: parseDouble(json['creatorEarn']),
      systemCommissionPercent: parseDouble(json['systemCommissionPercent']),
      paymentMethod: parseInt(json['paymentMethod']),
      paymentMethodText: json['paymentMethodText']?.toString() ?? '',
      note: json['note']?.toString(),
      createdDriverId: parseNullableInt(json['createdDriverId']),
      createdDriverName: json['createdDriverName']?.toString(),
      acceptedDriverId: parseNullableInt(json['acceptedDriverId']),
      acceptedDriverName: json['acceptedDriverName']?.toString(),
    );
  }
}
