class PaginatedResponse<T> {
  final List<T> items;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final bool hasMore;

  const PaginatedResponse({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.hasMore,
  });

  factory PaginatedResponse.fromJson(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    // Null / empty body → return empty page
    if (raw == null) {
      return const PaginatedResponse(
        items: [],
        totalElements: 0,
        totalPages: 0,
        currentPage: 0,
        hasMore: false,
      );
    }
    // Some endpoints return a bare array instead of a Spring Page object
    if (raw is List) {
      final items = raw
          .map((item) => fromJson(
                item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map),
              ))
          .toList();
      return PaginatedResponse(
        items: items,
        totalElements: items.length,
        totalPages: 1,
        currentPage: 0,
        hasMore: false,
      );
    }
    // Unexpected non-Map type (e.g. HTML error body parsed as String)
    if (raw is! Map) {
      return const PaginatedResponse(
        items: [],
        totalElements: 0,
        totalPages: 0,
        currentPage: 0,
        hasMore: false,
      );
    }
    final json = raw is Map<String, dynamic>
      ? raw
      : Map<String, dynamic>.from(raw);

    // Shapes supported:
    // - content[] (Spring & custom)
    // - items[] (audit, invitations)
    final rawList = (json['content'] as List?) ?? (json['items'] as List?) ?? [];

    final items = rawList
      .map((item) => fromJson(
          item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map),
        ))
      .toList();

    // 'page' (custom) or 'number' (Spring)
    final currentPage =
      (json['page'] as num?)?.toInt() ?? (json['number'] as num?)?.toInt() ?? 0;

    // 'pageSize' (custom) or 'size' (Spring)
    final pageSize = (json['pageSize'] as num?)?.toInt() ??
      (json['size'] as num?)?.toInt() ??
      (items.isNotEmpty ? items.length : 20);

    // 'totalElements' (Spring/custom) or 'total' (items-array style)
    final totalElements = (json['totalElements'] as num?)?.toInt() ??
      (json['total'] as num?)?.toInt() ??
      (items.isNotEmpty ? items.length : 0);

    final totalPagesFromServer = (json['totalPages'] as num?)?.toInt();
    final totalPages = totalPagesFromServer ??
      (pageSize > 0 ? ((totalElements + pageSize - 1) ~/ pageSize) : 1);

    // Some endpoints provide 'last' (Spring). If missing, infer from page/totalPages.
    final last = json.containsKey('last')
      ? (json['last'] as bool? ?? true)
      : (currentPage >= (totalPages - 1));

    final hasMore = !last && items.isNotEmpty;

    return PaginatedResponse(
      items: items,
      totalElements: totalElements,
      totalPages: totalPages,
      currentPage: currentPage,
      hasMore: hasMore,
    );
  }
}

class PageParams {
  final int page;
  final int size;
  final String? search;
  final Map<String, dynamic>? extra;

  const PageParams({
    this.page = 0,
    this.size = 10,
    this.search,
    this.extra,
  });

  Map<String, dynamic> toQueryParams() => {
        'page': page,
        // Compatibility: some endpoints expect Spring's 'size', others expect 'pageSize'.
        'size': size,
        'pageSize': size,
        if (search != null && search!.isNotEmpty) 'search': search,
        if (extra != null) ...extra!,
      };
}
