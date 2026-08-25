class ConcertTicketVerification {
  const ConcertTicketVerification({
    required this.isValid,
    required this.status,
    required this.message,
    this.ticketCode,
    this.orderCode,
    this.customerName,
    this.customerPhone,
    this.eventName,
    this.serviceName,
    this.serviceDate,
    this.direction,
    this.routeName,
    this.stopName,
    this.vehicleTypeName,
    this.resultCode,
    this.usedAt,
    this.totalGuests,
    this.checkedInGuests,
    this.remainingGuests,
  });

  factory ConcertTicketVerification.fromJson(Map<String, dynamic> json) {
    final ticket = _asMap(json['ticket']);
    final order = _asMap(json['order']);
    final customer = _asMap(json['customer']);
    final service = _asMap(json['service']);

    return ConcertTicketVerification(
      isValid:
          _asBool(json['isValid']) ??
          _asBool(json['valid']) ??
          _asBool(json['success']) ??
          false,
      status: _asString(json['status'] ?? ticket['status']),
      message: _asString(
        json['message'] ??
            json['reason'] ??
            json['error'] ??
            (json['success'] == false ? 'Vé không hợp lệ.' : 'Đã kiểm vé.'),
      ),
      ticketCode: _asNullableString(json['ticketCode'] ?? ticket['ticketCode']),
      orderCode: _asNullableString(json['orderCode'] ?? order['orderCode']),
      customerName: _asNullableString(
        json['customerName'] ?? customer['fullName'] ?? customer['name'],
      ),
      customerPhone: _asNullableString(
        json['customerPhone'] ?? customer['phone'],
      ),
      eventName: _asNullableString(json['eventName']),
      serviceName: _asNullableString(
        json['serviceName'] ?? service['name'] ?? ticket['serviceName'],
      ),
      serviceDate: _asNullableString(
        json['serviceDate'] ?? service['serviceDate'] ?? ticket['serviceDate'],
      ),
      direction: _asNullableString(
        json['direction'] ?? service['direction'] ?? ticket['direction'],
      ),
      routeName: _asNullableString(json['routeName'] ?? ticket['routeName']),
      stopName: _asNullableString(json['stopName'] ?? ticket['stopName']),
      vehicleTypeName: _asNullableString(
        json['vehicleTypeName'] ?? ticket['vehicleTypeName'],
      ),
      resultCode: _asNullableString(json['resultCode']),
      usedAt: _asNullableString(json['usedAt'] ?? ticket['usedAt']),
      totalGuests: _asNullableInt(
        json['totalGuests'] ?? json['totalQuantity'] ?? json['quantity'],
      ),
      checkedInGuests: _asNullableInt(
        json['checkedInGuests'] ?? json['checkedInQuantity'] ?? json['used'],
      ),
      remainingGuests: _asNullableInt(
        json['remainingGuests'] ??
            json['remainingQuantity'] ??
            json['remaining'],
      ),
    );
  }

  final bool isValid;
  final String status;
  final String message;
  final String? ticketCode;
  final String? orderCode;
  final String? customerName;
  final String? customerPhone;
  final String? eventName;
  final String? serviceName;
  final String? serviceDate;
  final String? direction;
  final String? routeName;
  final String? stopName;
  final String? vehicleTypeName;
  final String? resultCode;
  final String? usedAt;
  final int? totalGuests;
  final int? checkedInGuests;
  final int? remainingGuests;

  String get directionLabel {
    if (direction == 'OUTBOUND') return 'Vé lượt đi';
    if (direction == 'RETURN') return 'Vé lượt về';
    return direction ?? 'Chưa xác định';
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  return value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

String _asString(dynamic value) {
  return value?.toString().trim() ?? '';
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == 'valid') return true;
    if (normalized == 'false' || normalized == 'invalid') return false;
  }
  return null;
}
