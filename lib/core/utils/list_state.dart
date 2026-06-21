import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/utils/debounce.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ListState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;
  final int totalElements;
  final String searchQuery;
  final int pageSize;

  const ListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 0,
    this.hasMore = false,
    this.totalElements = 0,
    this.searchQuery = '',
    this.pageSize = 10,
  });

  ListState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
    int? totalElements,
    String? searchQuery,
    int? pageSize,
    bool clearError = false,
  }) {
    return ListState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      totalElements: totalElements ?? this.totalElements,
      searchQuery: searchQuery ?? this.searchQuery,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

abstract class ListNotifier<T> extends StateNotifier<ListState<T>> {
  final Debounce _debounce = Debounce();

  ListNotifier() : super(ListState<T>(isLoading: true)) {
    loadPage(0);
  }

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  Future<PaginatedResponse<T>> fetchPage(PageParams params);

  Future<void> loadPage(int page, {bool append = false}) async {
    if (append) {
      state = state.copyWith(isLoadingMore: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final params = PageParams(
          page: page, size: state.pageSize, search: state.searchQuery);
      final response = await fetchPage(params);
      state = state.copyWith(
        items: append ? [...state.items, ...response.items] : response.items,
        page: page,
        hasMore: response.hasMore,
        totalElements: response.totalElements,
        isLoading: false,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: ErrorHandler.handle(e).message,
      );
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _debounce.run(() => loadPage(0));
  }

  void reload() => loadPage(0);

  void setPageSize(int pageSize) {
    state = state.copyWith(pageSize: pageSize);
    loadPage(0);
  }

  void loadMore() {
    if (!state.isLoadingMore && state.hasMore) {
      loadPage(state.page + 1, append: true);
    }
  }

  /// Attach this to a [NotificationListener<ScrollNotification>] to enable
  /// infinite scroll without repeating logic in each screen.
  bool onScrollNotification(ScrollNotification notification,
      {double thresholdPx = 240}) {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;

    // When remaining scroll extent is small, load the next page.
    if (metrics.extentAfter <= thresholdPx) {
      loadMore();
    }
    return false;
  }
}
