import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiChatService {
  ApiChatService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final Future<String?> Function() tokenProvider;
  final http.Client _client;

  static const String baseUrl = 'https://belucar.com/api';

  Map<String, String> _headers({bool isJson = false}) {
    return {
      if (isJson) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, String>> _authHeaders({bool isJson = false}) async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException('Missing driver JWT token');
    }

    return {..._headers(isJson: isJson), 'Authorization': 'Bearer $token'};
  }

  Uri _uri(String path, {Map<String, dynamic>? queryParameters}) {
    final uri = Uri.parse('$baseUrl$path');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  T _unwrapData<T>(http.Response response, T Function(dynamic json) parser) {
    final decoded = _decodeBody(response);

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Invalid response format',
        statusCode: response.statusCode,
      );
    }

    final success = decoded['success'] == true;
    if (!success) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }

    return parser(decoded['data']);
  }

  Never _throwHttpError(http.Response response) {
    final decoded = _decodeBody(response);
    if (decoded is Map<String, dynamic>) {
      throw ApiException(
        decoded['message']?.toString() ?? 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}',
      statusCode: response.statusCode,
    );
  }

  Future<List<DriverChatGroupDto>> getDriverGroups() async {
    final response = await _client.get(
      _uri('/chat/driver-groups'),
      headers: await _authHeaders(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwHttpError(response);
    }

    return _unwrapData(response, (json) {
      final list = (json as List<dynamic>? ?? []);
      return list
          .map((e) => DriverChatGroupDto.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<DriverChatGroupDto> getDriverGroupDetail(int groupId) async {
    final response = await _client.get(
      _uri('/chat/driver-groups/$groupId'),
      headers: await _authHeaders(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwHttpError(response);
    }

    return _unwrapData(
      response,
      (json) => DriverChatGroupDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<DriverChatMessagePageDto> getDriverGroupMessages({
    required int groupId,
    int take = 30,
    int? beforeMessageId,
  }) async {
    final query = <String, dynamic>{
      'take': take,
      if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
    };

    final response = await _client.get(
      _uri('/chat/driver-groups/$groupId/messages', queryParameters: query),
      headers: await _authHeaders(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwHttpError(response);
    }

    return _unwrapData(
      response,
      (json) => DriverChatMessagePageDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<DriverChatGroupMessageDto> sendTextMessage({
    required int groupId,
    required String content,
  }) async {
    final response = await _client.post(
      _uri('/chat/driver-groups/$groupId/messages'),
      headers: await _authHeaders(isJson: true),
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwHttpError(response);
    }

    return _unwrapData(
      response,
      (json) =>
          DriverChatGroupMessageDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> markGroupAsRead(int groupId) async {
    final response = await _client.post(
      _uri('/chat/driver-groups/$groupId/mark-read'),
      headers: await _authHeaders(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwHttpError(response);
    }

    final decoded = _decodeBody(response);
    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Mark read failed',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException($statusCode): $message';
    }
    return 'ApiException: $message';
  }
}

class DriverChatGroupDto {
  DriverChatGroupDto({
    required this.id,
    required this.name,
    required this.description,
    required this.audienceType,
    required this.isActive,
    required this.createdByAdminId,
    required this.createdByAdminName,
    required this.lastMessagePreview,
    required this.lastMessageSenderType,
    required this.lastMessageType,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final int id;
  final String? name;
  final String? description;
  final int? audienceType;
  final bool isActive;
  final int? createdByAdminId;
  final String? createdByAdminName;
  final String? lastMessagePreview;
  final int? lastMessageSenderType;
  final int? lastMessageType;
  final DateTime? lastMessageAt;
  final int unreadCount;

  factory DriverChatGroupDto.fromJson(Map<String, dynamic> json) {
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

    return DriverChatGroupDto(
      id: parseInt(json['id']),
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      audienceType: parseNullableInt(json['audienceType']),
      isActive: json['isActive'] == true,
      createdByAdminId: parseNullableInt(json['createdByAdminId']),
      createdByAdminName: json['createdByAdminName']?.toString(),
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      lastMessageSenderType: parseNullableInt(json['lastMessageSenderType']),
      lastMessageType: parseNullableInt(json['lastMessageType']),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      unreadCount: parseInt(json['unreadCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'audienceType': audienceType,
      'isActive': isActive,
      'createdByAdminId': createdByAdminId,
      'createdByAdminName': createdByAdminName,
      'lastMessagePreview': lastMessagePreview,
      'lastMessageSenderType': lastMessageSenderType,
      'lastMessageType': lastMessageType,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }
}

class DriverChatMessagePageDto {
  DriverChatMessagePageDto({
    required this.items,
    required this.hasMore,
    required this.nextBeforeMessageId,
  });

  final List<DriverChatGroupMessageDto> items;
  final bool hasMore;
  final int? nextBeforeMessageId;

  factory DriverChatMessagePageDto.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return DriverChatMessagePageDto(
      items: itemsJson
          .map(
            (e) =>
                DriverChatGroupMessageDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      hasMore: json['hasMore'] == true,
      nextBeforeMessageId: parseNullableInt(json['nextBeforeMessageId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'hasMore': hasMore,
      'nextBeforeMessageId': nextBeforeMessageId,
    };
  }
}

class DriverChatGroupMessageDto {
  DriverChatGroupMessageDto({
    required this.id,
    required this.groupId,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.content,
    required this.metadataJson,
    required this.createdAt,
  });

  final int id;
  final int groupId;
  final int senderType;
  final int? senderId;
  final String? senderName;
  final int messageType;
  final String? content;
  final String? metadataJson;
  final DateTime? createdAt;

  factory DriverChatGroupMessageDto.fromJson(Map<String, dynamic> json) {
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

    return DriverChatGroupMessageDto(
      id: parseInt(json['id']),
      groupId: parseInt(json['groupId']),
      senderType: parseInt(json['senderType']),
      senderId: parseNullableInt(json['senderId']),
      senderName: json['senderName']?.toString(),
      messageType: parseInt(json['messageType']),
      content: json['content']?.toString(),
      metadataJson: json['metadataJson']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  DriverChatGroupBrokerRideCardDto? tryParseBrokerRideCard() {
    if (messageType != 2 || metadataJson == null || metadataJson!.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(metadataJson!);
      if (decoded is Map<String, dynamic>) {
        return DriverChatGroupBrokerRideCardDto.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'senderType': senderType,
      'senderId': senderId,
      'senderName': senderName,
      'messageType': messageType,
      'content': content,
      'metadataJson': metadataJson,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class DriverChatGroupBrokerRideCardDto {
  DriverChatGroupBrokerRideCardDto({
    required this.brokerRideId,
    required this.groupId,
    required this.code,
    required this.status,
    required this.type,
    required this.quantity,
    required this.pickupTime,
    required this.fromDistrictId,
    required this.fromDistrictName,
    required this.fromAddress,
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

  final int brokerRideId;
  final int? groupId;
  final String? code;
  final int? status;
  final int? type;
  final int? quantity;
  final DateTime? pickupTime;
  final int? fromDistrictId;
  final String? fromDistrictName;
  final String? fromAddress;
  final int? toDistrictId;
  final String? toDistrictName;
  final String? toAddress;
  final String? customerPhone;
  final num? offerPrice;
  final num? acceptedPrice;
  final num? creatorEarn;
  final num? systemCommissionPercent;
  final int? paymentMethod;
  final String? paymentMethodText;
  final String? note;
  final int? createdDriverId;
  final String? createdDriverName;
  final int? acceptedDriverId;
  final String? acceptedDriverName;

  factory DriverChatGroupBrokerRideCardDto.fromJson(Map<String, dynamic> json) {
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

    return DriverChatGroupBrokerRideCardDto(
      brokerRideId: parseInt(json['brokerRideId']),
      groupId: parseNullableInt(json['groupId']),
      code: json['code']?.toString(),
      status: parseNullableInt(json['status']),
      type: parseNullableInt(json['type']),
      quantity: parseNullableInt(json['quantity']),
      pickupTime: json['pickupTime'] != null
          ? DateTime.tryParse(json['pickupTime'].toString())
          : null,
      fromDistrictId: parseNullableInt(json['fromDistrictId']),
      fromDistrictName: json['fromDistrictName']?.toString(),
      fromAddress: json['fromAddress']?.toString(),
      toDistrictId: parseNullableInt(json['toDistrictId']),
      toDistrictName: json['toDistrictName']?.toString(),
      toAddress: json['toAddress']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      offerPrice: json['offerPrice'] as num?,
      acceptedPrice: json['acceptedPrice'] as num?,
      creatorEarn: json['creatorEarn'] as num?,
      systemCommissionPercent: json['systemCommissionPercent'] as num?,
      paymentMethod: parseNullableInt(json['paymentMethod']),
      paymentMethodText: json['paymentMethodText']?.toString(),
      note: json['note']?.toString(),
      createdDriverId: parseNullableInt(json['createdDriverId']),
      createdDriverName: json['createdDriverName']?.toString(),
      acceptedDriverId: parseNullableInt(json['acceptedDriverId']),
      acceptedDriverName: json['acceptedDriverName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brokerRideId': brokerRideId,
      'groupId': groupId,
      'code': code,
      'status': status,
      'type': type,
      'quantity': quantity,
      'pickupTime': pickupTime?.toIso8601String(),
      'fromDistrictId': fromDistrictId,
      'fromDistrictName': fromDistrictName,
      'fromAddress': fromAddress,
      'toDistrictId': toDistrictId,
      'toDistrictName': toDistrictName,
      'toAddress': toAddress,
      'customerPhone': customerPhone,
      'offerPrice': offerPrice,
      'acceptedPrice': acceptedPrice,
      'creatorEarn': creatorEarn,
      'systemCommissionPercent': systemCommissionPercent,
      'paymentMethod': paymentMethod,
      'paymentMethodText': paymentMethodText,
      'note': note,
      'createdDriverId': createdDriverId,
      'createdDriverName': createdDriverName,
      'acceptedDriverId': acceptedDriverId,
      'acceptedDriverName': acceptedDriverName,
    };
  }
}

abstract class DriverChatAudienceType {
  static const int allDrivers = 1;
}

abstract class DriverChatSenderType {
  static const int admin = 1;
  static const int driver = 2;
  static const int system = 3;
}

abstract class DriverChatMessageType {
  static const int text = 1;
  static const int brokerRideCard = 2;
}

abstract class BrokerRideStatus {
  static const int findingDriver = 1;
  static const int accepted = 2;
  static const int inProgress = 3;
  static const int completed = 4;
  static const int cancelled = 5;
}

abstract class RideSource {
  static const int brokerRide = 2;
}
