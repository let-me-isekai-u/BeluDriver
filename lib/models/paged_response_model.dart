class PagedResponse<T> {
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final List<T> data;

  PagedResponse({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.data,
  });

  factory PagedResponse.fromJson(
      Map<String, dynamic> json,
      T Function(Object? json) fromJsonT,
      ) {
    return PagedResponse<T>(
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? 20,
      totalItems: json['totalItems'] ?? 0,
      totalPages: json['totalPages'] ?? 1,
      hasNext: json['hasNext'] ?? false,
      // ĐỔI TỪ json['data'] THÀNH json['items'] Ở ĐÂY:
      data: (json['items'] as List<dynamic>? ?? [])
          .map((e) => fromJsonT(e))
          .toList(),
    );
  }
}
