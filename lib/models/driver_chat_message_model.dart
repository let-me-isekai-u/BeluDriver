import 'dart:convert';

import 'driver_chat_broker_ride_meta_model.dart';

class DriverChatMessageModel {
  final int id;
  final int groupId;
  final int senderType;
  final int? senderId;
  final String senderName;
  final int messageType;
  final String content;
  final String? metadataJson;
  final DateTime? createdAt;

  DriverChatMessageModel({
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

  factory DriverChatMessageModel.fromJson(Map<String, dynamic> json) {
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

    return DriverChatMessageModel(
      id: parseInt(json['id']),
      groupId: parseInt(json['groupId']),
      senderType: parseInt(json['senderType']),
      senderId: parseNullableInt(json['senderId']),
      senderName: json['senderName']?.toString() ?? '',
      messageType: parseInt(json['messageType']),
      content: json['content']?.toString() ?? '',
      metadataJson: json['metadataJson']?.toString(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
    );
  }

  DriverChatBrokerRideMetaModel? get brokerRideMeta {
    if (messageType != 2) return null;
    if (metadataJson == null || metadataJson!.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(metadataJson!);
      if (decoded is Map<String, dynamic>) {
        return DriverChatBrokerRideMetaModel.fromJson(decoded);
      }
      if (decoded is Map) {
        return DriverChatBrokerRideMetaModel.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}

    return null;
  }

  bool get isTextMessage => messageType == 1;
  bool get isBrokerRideCard => messageType == 2;
}