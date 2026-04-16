import 'driver_chat_message_model.dart';

class DriverChatMessagesPage {
  final List<DriverChatMessageModel> items;
  final bool hasMore;
  final int? nextBeforeMessageId;

  DriverChatMessagesPage({
    required this.items,
    required this.hasMore,
    required this.nextBeforeMessageId,
  });

  factory DriverChatMessagesPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return DriverChatMessagesPage(
      items: rawItems
          .map((e) => DriverChatMessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasMore: json['hasMore'] == true,
      nextBeforeMessageId: parseNullableInt(json['nextBeforeMessageId']),
    );
  }
}