import 'dart:math' as math;

import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum DashboardScope { general, products, sales, marketing, warehouse }

enum DashboardPeriod { today, threeDays, sevenDays, all }

final dashboardPeriodProvider =
    StateProvider.autoDispose.family<DashboardPeriod, DashboardScope>(
  (ref, scope) => DashboardPeriod.today,
);

class DashboardData {
  final int products;
  final int activeProducts;
  final int draftProducts;
  final int featuredProducts;
  final int quotes;
  final int quoteDrafts;
  final int quoteSent;
  final int quoteWon;
  final double quoteAmount;
  final int leads;
  final int featured;
  final int campaigns;
  final int coupons;
  final int sellers;
  final int people;
  final int users;
  final int warehouses;
  final int stockRows;
  final int apiRequests;
  final int api2xx;
  final int apiErrors;
  final int apiP95Ms;
  final int apiAvgMs;
  final List<ServiceStat> services;
  final List<RecentTrace> traces;
  final List<RecentQuote> recentQuotes;
  final Map<String, ProductLookup> productsById;

  const DashboardData({
    required this.products,
    required this.activeProducts,
    required this.draftProducts,
    required this.featuredProducts,
    required this.quotes,
    required this.quoteDrafts,
    required this.quoteSent,
    required this.quoteWon,
    required this.quoteAmount,
    required this.leads,
    required this.featured,
    required this.campaigns,
    required this.coupons,
    required this.sellers,
    required this.people,
    required this.users,
    required this.warehouses,
    required this.stockRows,
    required this.apiRequests,
    required this.api2xx,
    required this.apiErrors,
    required this.apiP95Ms,
    required this.apiAvgMs,
    required this.services,
    required this.traces,
    required this.recentQuotes,
    required this.productsById,
  });
}

class ProductLookup {
  final String name;
  final String sku;

  const ProductLookup({
    required this.name,
    required this.sku,
  });
}

class ServiceStat {
  final String name;
  final int requests;
  final int ok;
  final int errors;
  final int p95Ms;
  final int totalMs;

  const ServiceStat({
    required this.name,
    required this.requests,
    required this.ok,
    required this.errors,
    required this.p95Ms,
    required this.totalMs,
  });
}

class RecentTrace {
  final String service;
  final String method;
  final int status;
  final int durationMs;
  final int payloadBytes;

  const RecentTrace({
    required this.service,
    required this.method,
    required this.status,
    required this.durationMs,
    required this.payloadBytes,
  });
}

class MarketingDashboardDetails {
  final int events;
  final int productViews;
  final int productLikes;
  final int featuredViews;
  final int featuredClicks;
  final int whatsappClicks;
  final int quoteRequests;
  final int conversions;
  final int leads;
  final List<MarketingFunnelMetric> funnel;
  final List<MarketingProductMetric> topProducts;

  const MarketingDashboardDetails({
    required this.events,
    required this.productViews,
    required this.productLikes,
    required this.featuredViews,
    required this.featuredClicks,
    required this.whatsappClicks,
    required this.quoteRequests,
    required this.conversions,
    required this.leads,
    required this.funnel,
    required this.topProducts,
  });
}

class MarketingFunnelMetric {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const MarketingFunnelMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class MarketingProductMetric {
  final String productId;
  final int impressions;
  final int views;
  final int likes;
  final int quoteRequests;
  final int featuredViews;

  const MarketingProductMetric({
    required this.productId,
    required this.impressions,
    required this.views,
    required this.likes,
    required this.quoteRequests,
    required this.featuredViews,
  });
}

class ProductDashboardDetails {
  final int products;
  final int activeProducts;
  final int draftProducts;
  final int featuredProducts;

  const ProductDashboardDetails({
    required this.products,
    required this.activeProducts,
    required this.draftProducts,
    required this.featuredProducts,
  });
}

class SalesDashboardDetails {
  final int quotes;
  final int draft;
  final int sent;
  final int won;
  final double amount;
  final List<RecentQuote> recentQuotes;

  const SalesDashboardDetails({
    required this.quotes,
    required this.draft,
    required this.sent,
    required this.won,
    required this.amount,
    required this.recentQuotes,
  });
}

class WarehouseDashboardDetails {
  final int warehouses;
  final int activeWarehouses;
  final int stockRows;
  final int movements;

  const WarehouseDashboardDetails({
    required this.warehouses,
    required this.activeWarehouses,
    required this.stockRows,
    required this.movements,
  });
}

class RecentQuote {
  final String number;
  final String customer;
  final String status;
  final double amount;
  final DateTime? createdAt;

  const RecentQuote({
    required this.number,
    required this.customer,
    required this.status,
    required this.amount,
    this.createdAt,
  });
}

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final dio = ref.watch(dioProvider);

  final products = await _getPage(dio, '/v1/products', size: 80);
  final quotes = await _getPage(dio, '/v1/quotes', size: 80);
  final leads = await _getPage(dio, '/v1/leads', size: 1);
  final featured = await _getPage(dio, '/v1/products', size: 1, extra: {'featured': true});
  final campaigns = await _getPage(dio, '/v1/campaigns', size: 20);
  final coupons = await _getPage(dio, '/v1/coupons', size: 1);
  final sellers = await _getPage(dio, '/v1/sellers', size: 1);
  final people = await _getPage(dio, '/v1/people', size: 1);
  final users = await _getPage(dio, '/v1/users', size: 1);
  final warehouses = await _getPage(dio, '/v1/warehouses', size: 1);
  final stock = await _getPage(dio, '/v1/warehouse/stock', size: 1);
  final traces = await _getPage(dio, '/v1/apitraces', size: 120);

  final productItems = products.items;
  final quoteItems = quotes.items;
  final traceItems = traces.items;

  final durations = traceItems
      .map(_traceDurationMs)
      .where((value) => value > 0)
      .toList()
    ..sort();

  final services = _serviceStats(traceItems);

  return DashboardData(
    products: products.total,
    activeProducts: productItems.where((item) => _status(item) == 'ACTIVE').length,
    draftProducts: productItems.where((item) => _status(item) == 'DRAFT').length,
    featuredProducts: productItems.where((item) => _boolAny(item, ['featured', 'isFeatured'])).length,
    quotes: quotes.total,
    quoteDrafts: quoteItems.where((item) => _status(item) == 'DRAFT').length,
    quoteSent: quoteItems.where((item) => _status(item) == 'SENT').length,
    quoteWon: quoteItems.where((item) => _status(item) == 'WON').length,
    quoteAmount: quoteItems.fold<double>(0, (sum, item) => sum + _doubleAny(item, ['totalAmount', 'total'])),
    leads: leads.total,
    featured: featured.total,
    campaigns: campaigns.total,
    coupons: coupons.total,
    sellers: sellers.total,
    people: people.total,
    users: users.total,
    warehouses: warehouses.total,
    stockRows: stock.total,
    apiRequests: traceItems.length,
    api2xx: traceItems.where((item) {
      final status = _intAny(item, ['httpResponseCode', 'status']);
      return status >= 200 && status < 300;
    }).length,
    apiErrors: traceItems.where((item) => _intAny(item, ['httpResponseCode', 'status']) >= 400).length,
    apiP95Ms: _percentile(durations, 0.95),
    apiAvgMs: durations.isEmpty ? 0 : (durations.reduce((a, b) => a + b) / durations.length).round(),
    services: services,
    traces: traceItems.take(8).map((item) => RecentTrace(
      service: _stringAny(item, ['serviceName', 'service', 'targetService'], fallback: 'servicio'),
      method: _stringAny(item, ['httpMethod', 'method'], fallback: 'GET'),
      status: _intAny(item, ['httpResponseCode', 'status']),
      durationMs: _traceDurationMs(item),
      payloadBytes: _tracePayloadBytes(item),
    )).toList(),
    recentQuotes: quoteItems.take(8).map((item) => RecentQuote(
      number: _stringAny(item, ['quoteNumber', 'number'], fallback: 'Cotizacion'),
      customer: _customerName(item),
      status: _status(item, fallback: 'DRAFT'),
      amount: _doubleAny(item, ['totalAmount', 'total']),
      createdAt: _dateAny(item, ['createdDate', 'createdAt']),
    )).toList(),
    productsById: {
      for (final item in productItems)
        if (_stringAny(item, ['id', 'productId']).isNotEmpty)
          _stringAny(item, ['id', 'productId']): ProductLookup(
            name: _stringAny(item, ['name', 'productName'], fallback: 'Producto'),
            sku: _stringAny(item, ['sku', 'code'], fallback: ''),
          ),
    },
  );
});

final productDashboardDetailsProvider =
    FutureProvider.autoDispose.family<ProductDashboardDetails, DashboardPeriod>((ref, period) async {
  final dio = ref.watch(dioProvider);
  final summary = await _getMap(
    dio,
    '/v1/products/reporting/summary',
    extra: {'period': _periodCode(period)},
  );

  if (summary.isEmpty) {
    final products = await _getPage(dio, '/v1/products', size: 500);
    return ProductDashboardDetails(
      products: products.total,
      activeProducts: products.items.where((item) => _status(item) == 'ACTIVE').length,
      draftProducts: products.items.where((item) => _status(item) == 'DRAFT').length,
      featuredProducts: products.items.where((item) => _boolAny(item, ['featured', 'isFeatured'])).length,
    );
  }

  return ProductDashboardDetails(
    products: _intAny(summary, ['products', 'totalProducts', 'total']),
    activeProducts: _intAny(summary, ['activeProducts', 'active']),
    draftProducts: _intAny(summary, ['draftProducts', 'drafts', 'draft']),
    featuredProducts: _intAny(summary, ['featuredProducts', 'featured']),
  );
});

final salesDashboardDetailsProvider =
    FutureProvider.autoDispose.family<SalesDashboardDetails, DashboardPeriod>((ref, period) async {
  final dio = ref.watch(dioProvider);
  final quotes = await _getPage(
    dio,
    '/v1/quotes',
    size: 500,
    extra: _quotePeriodParams(period),
  );
  final quoteItems = quotes.items;
  final recentQuotes = quoteItems.map((item) => RecentQuote(
    number: _stringAny(item, ['quoteNumber', 'number'], fallback: 'Cotizacion'),
    customer: _customerName(item),
    status: _status(item, fallback: 'DRAFT'),
    amount: _doubleAny(item, ['totalAmount', 'total']),
    createdAt: _dateAny(item, ['createdDate', 'createdAt']),
  )).toList();

  final draft = recentQuotes.where((quote) => quote.status == 'DRAFT').length;
  final sent = recentQuotes.where((quote) => quote.status == 'SENT').length;
  final won = recentQuotes.where((quote) => quote.status == 'WON').length;

  return SalesDashboardDetails(
    quotes: quotes.total > recentQuotes.length ? quotes.total : recentQuotes.length,
    draft: draft,
    sent: sent,
    won: won,
    amount: recentQuotes.fold<double>(0, (sum, quote) => sum + quote.amount),
    recentQuotes: recentQuotes.take(8).toList(),
  );
});

final warehouseDashboardDetailsProvider =
    FutureProvider.autoDispose.family<WarehouseDashboardDetails, DashboardPeriod>((ref, period) async {
  final dio = ref.watch(dioProvider);
  final summary = await _getMap(
    dio,
    '/v1/warehouse/reporting/summary',
    extra: {'period': _periodCode(period)},
  );

  if (summary.isEmpty) {
    final warehouses = await _getPage(dio, '/v1/warehouses', size: 200);
    final stock = await _getPage(dio, '/v1/warehouse/stock', size: 200);
    return WarehouseDashboardDetails(
      warehouses: warehouses.total,
      activeWarehouses: warehouses.items.where((item) => _boolAny(item, ['active', 'enabled'])).length,
      stockRows: stock.total,
      movements: 0,
    );
  }

  return WarehouseDashboardDetails(
    warehouses: _intAny(summary, ['warehouses']),
    activeWarehouses: _intAny(summary, ['activeWarehouses']),
    stockRows: _intAny(summary, ['stockItems', 'stockRows']),
    movements: _intAny(summary, ['movements']),
  );
});

final marketingDashboardDetailsProvider =
    FutureProvider.autoDispose.family<MarketingDashboardDetails, DashboardPeriod>((ref, period) async {
  final dio = ref.watch(dioProvider);
  final auth = ref.watch(authNotifierProvider);
  final periodCode = _periodCode(period);
  final scope = await _marketingScope(dio, auth, periodCode);
  Map<String, dynamic> scoped(Map<String, dynamic> extra) => {
        ...scope,
        ...extra,
      };

  final summary = await _getMap(
    dio,
    '/v1/campaigns/reporting/summary',
    extra: scoped({'period': periodCode}),
  );
  final topProducts = await _getList(
    dio,
    '/v1/campaigns/reporting/products/top',
    extra: scoped({'period': periodCode, 'limit': 3}),
  );
  final actions = await _getList(
    dio,
    '/v1/campaigns/reporting/actions/top',
    extra: scoped({'period': periodCode, 'limit': 16}),
  );
  final funnel = await _getMap(
    dio,
    '/v1/marketing/funnels/evaluate',
    extra: scoped({'period': periodCode}),
  );
  final actionEvents = actions.fold<int>(0, (sum, item) => sum + _intAny(item, ['count', 'total']));
  final productViews = topProducts.fold<int>(0, (sum, item) => sum + _intAny(item, ['productViews', 'views']));
  final productLikes = topProducts.fold<int>(0, (sum, item) => sum + _intAny(item, ['likes']));
  final productQuotes = topProducts.fold<int>(0, (sum, item) => sum + _intAny(item, ['quoteRequests']));
  final productFeaturedViews = topProducts.fold<int>(0, (sum, item) => sum + _intAny(item, ['featuredViews', 'impressions']));

  return MarketingDashboardDetails(
    events: _firstPositive([_intAny(summary, ['events']), actionEvents]),
    productViews: _firstPositive([_intAny(summary, ['productViews']), productViews]),
    productLikes: _firstPositive([_intAny(summary, ['productLikes']), productLikes]),
    featuredViews: _firstPositive([_intAny(summary, ['featuredViews']), productFeaturedViews]),
    featuredClicks: _intAny(summary, ['featuredClicks']),
    whatsappClicks: _intAny(summary, ['whatsappClicks']),
    quoteRequests: _firstPositive([_intAny(summary, ['quoteRequests']), productQuotes]),
    conversions: _intAny(summary, ['conversions']),
    leads: _intAny(summary, ['leads']),
    funnel: _marketingFunnelMetrics(funnel, actions, summary),
    topProducts: topProducts.map((item) => MarketingProductMetric(
      productId: _stringAny(item, ['productId', 'id']),
      impressions: _intAny(item, ['impressions']),
      views: _intAny(item, ['productViews', 'views']),
      likes: _intAny(item, ['likes']),
      quoteRequests: _intAny(item, ['quoteRequests']),
      featuredViews: _intAny(item, ['featuredViews']),
    )).toList(),
  );
});

Future<Map<String, dynamic>> _marketingScope(
  Dio dio,
  AuthState auth,
  String periodCode,
) async {
  final params = <String, dynamic>{};
  final tenantId = auth.tenantId?.trim();
  if (tenantId != null && tenantId.isNotEmpty) {
    params['tenantId'] = tenantId;
  } else {
    final resolvedTenantId = await _resolveMarketingTenantId(dio, periodCode);
    if (resolvedTenantId != null && resolvedTenantId.isNotEmpty) {
      params['tenantId'] = resolvedTenantId;
    }
  }

  final sellerId = auth.sellerId?.trim();
  if (sellerId != null && sellerId.isNotEmpty) {
    params['sellerId'] = sellerId;
  }
  return params;
}

Future<String?> _resolveMarketingTenantId(Dio dio, String periodCode) async {
  final campaigns = await _getPage(dio, '/v1/campaigns', size: 50);
  final campaignTenantIds = <String>{};
  for (final campaign in campaigns.items) {
    final tenantId = _idAny(
      campaign,
      ['tenantId', 'companyId', 'tenant', 'company'],
    );
    if (tenantId.isNotEmpty) campaignTenantIds.add(tenantId);
  }

  for (final tenantId in campaignTenantIds) {
    final summary = await _getMap(
      dio,
      '/v1/campaigns/reporting/summary',
      extra: {'tenantId': tenantId, 'period': periodCode},
    );
    final hasMovement = _firstPositive([
          _intAny(summary, ['events']),
          _intAny(summary, ['productViews']),
          _intAny(summary, ['featuredViews']),
          _intAny(summary, ['quoteRequests']),
          _intAny(summary, ['leads']),
        ]) >
        0;
    if (hasMovement) return tenantId;
  }
  if (campaignTenantIds.isNotEmpty) return campaignTenantIds.first;

  final tenants = await _getPage(dio, '/v1/tenants', size: 50);
  for (final tenant in tenants.items) {
    final tenantId = _idAny(tenant, ['tenantId', 'id']);
    if (tenantId.isNotEmpty) return tenantId;
  }
  return null;
}

Future<_PageData> _getPage(
  Dio dio,
  String path, {
  int size = 20,
  Map<String, dynamic>? extra,
}) async {
  try {
    final resp = await dio.get(
      path,
      queryParameters: {
        'page': 0,
        'size': size,
        'pageSize': size,
        if (extra != null) ...extra,
      },
    );
    final data = resp.data;
    if (data is List) return _PageData(items: _maps(data), total: data.length);
    if (data is Map) {
      final items = (data['content'] as List?) ?? (data['items'] as List?) ?? const [];
      return _PageData(
        items: _maps(items),
        total: (data['totalElements'] as num?)?.toInt() ??
            (data['total'] as num?)?.toInt() ??
            items.length,
      );
    }
  } catch (_) {
    return const _PageData(items: [], total: 0);
  }
  return const _PageData(items: [], total: 0);
}

Future<Map<String, dynamic>> _getMap(
  Dio dio,
  String path, {
  Map<String, dynamic>? extra,
}) async {
  try {
    final resp = await dio.get(path, queryParameters: extra);
    final data = resp.data;
    if (data is Map) return Map<String, dynamic>.from(data);
  } catch (_) {
    return const {};
  }
  return const {};
}

Future<List<Map<String, dynamic>>> _getList(
  Dio dio,
  String path, {
  Map<String, dynamic>? extra,
}) async {
  try {
    final resp = await dio.get(path, queryParameters: extra);
    final data = resp.data;
    if (data is List) return _maps(data);
    if (data is Map) {
      final items = (data['content'] as List?) ?? (data['items'] as List?) ?? const [];
      return _maps(items);
    }
  } catch (_) {
    return const [];
  }
  return const [];
}

class _PageData {
  final List<Map<String, dynamic>> items;
  final int total;

  const _PageData({required this.items, required this.total});
}

List<Map<String, dynamic>> _maps(List<dynamic> values) => values
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList();

List<ServiceStat> _serviceStats(List<Map<String, dynamic>> traces) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final trace in traces) {
    final service = _stringAny(trace, ['serviceName', 'service', 'targetService'], fallback: 'servicio');
    grouped.putIfAbsent(service, () => []).add(trace);
  }

  final stats = grouped.entries.map((entry) {
    final durations = entry.value.map(_traceDurationMs).where((value) => value > 0).toList()..sort();
    final ok = entry.value.where((item) {
      final status = _intAny(item, ['httpResponseCode', 'status']);
      return status >= 200 && status < 300;
    }).length;
    final errors = entry.value.where((item) => _intAny(item, ['httpResponseCode', 'status']) >= 400).length;
    return ServiceStat(
      name: entry.key,
      requests: entry.value.length,
      ok: ok,
      errors: errors,
      p95Ms: _percentile(durations, 0.95),
      totalMs: durations.fold(0, (sum, value) => sum + value),
    );
  }).toList()
    ..sort((a, b) => b.requests.compareTo(a.requests));

  return stats.take(5).toList();
}

int _traceDurationMs(Map<String, dynamic> item) {
  final ms = _intAny(item, ['durationMs', 'executionTimeMs', 'elapsedMs']);
  if (ms > 0) return ms;
  final seconds = _doubleAny(item, ['executionTimeSeconds', 'durationSeconds']);
  return (seconds * 1000).round();
}

int _tracePayloadBytes(Map<String, dynamic> item) {
  final payload = _intAny(item, ['payloadSize', 'payloadBytes']);
  if (payload > 0) return payload;
  return _intAny(item, ['requestBodySizeBytes']) +
      _intAny(item, ['responseBodySizeBytes']);
}

List<MarketingFunnelMetric> _marketingFunnelMetrics(
  Map<String, dynamic> funnel,
  List<Map<String, dynamic>> actions,
  Map<String, dynamic> summary,
) {
  final steps = (funnel['steps'] as List?)?.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    return MarketingFunnelMetric(
      label: _stringAny(map, ['label', 'stepKey'], fallback: 'Paso'),
      value: _intAny(map, ['count']),
      icon: _marketingIcon(_stringAny(map, ['label', 'stepKey', 'category', 'eventType'])),
      color: _marketingColor(_stringAny(map, ['label', 'stepKey', 'category', 'eventType'])),
    );
  }).toList();

  if (steps != null && steps.isNotEmpty) return steps.take(4).toList();

  return [
    MarketingFunnelMetric(
      label: 'Presupuesto',
      value: _actionCount(actions, ['presupuesto', 'quote']) + _intAny(summary, ['quoteRequests']),
      icon: Icons.ads_click_rounded,
      color: const Color(0xFF00A676),
    ),
    MarketingFunnelMetric(
      label: 'Consultar stock',
      value: _actionCount(actions, ['stock']),
      icon: Icons.near_me_rounded,
      color: const Color(0xFFF59E0B),
    ),
    MarketingFunnelMetric(
      label: 'Compra mayorista',
      value: _actionCount(actions, ['mayorista', 'wholesale']),
      icon: Icons.groups_rounded,
      color: const Color(0xFFFF5A1F),
    ),
  ];
}

int _actionCount(List<Map<String, dynamic>> actions, List<String> tokens) {
  var total = 0;
  for (final action in actions) {
    final searchable = [
      _stringAny(action, ['actionCode']),
      _stringAny(action, ['actionLabel']),
      _stringAny(action, ['category']),
      _stringAny(action, ['eventType']),
    ].join(' ').toLowerCase();
    if (tokens.any((token) => searchable.contains(token))) {
      total += _intAny(action, ['count', 'total']);
    }
  }
  return total;
}

IconData _marketingIcon(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('stock')) return Icons.near_me_rounded;
  if (normalized.contains('mayorista') || normalized.contains('wholesale')) return Icons.groups_rounded;
  if (normalized.contains('like')) return Icons.favorite_rounded;
  return Icons.ads_click_rounded;
}

Color _marketingColor(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('stock')) return const Color(0xFFF59E0B);
  if (normalized.contains('mayorista') || normalized.contains('wholesale')) return const Color(0xFFFF5A1F);
  if (normalized.contains('like')) return const Color(0xFFDB2777);
  return const Color(0xFF00A676);
}

int _percentile(List<int> sorted, double percentile) {
  if (sorted.isEmpty) return 0;
  final index = math.min(sorted.length - 1, (sorted.length * percentile).ceil() - 1);
  return sorted[index];
}

String _status(Map<String, dynamic> item, {String fallback = ''}) =>
    _stringAny(item, ['status', 'state'], fallback: fallback).toUpperCase();

String _customerName(Map<String, dynamic> item) {
  final first = _stringAny(item, ['customerFirstName', 'firstName']);
  final last = _stringAny(item, ['customerLastName', 'lastName']);
  final full = [first, last].where((value) => value.trim().isNotEmpty).join(' ');
  return full.isNotEmpty ? full : _stringAny(item, ['customerName', 'clientName'], fallback: 'Cliente');
}

String _stringAny(Map<String, dynamic> item, List<String> keys, {String fallback = ''}) {
  for (final key in keys) {
    final value = item[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

String _idAny(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value is String && value.trim().isNotEmpty && value.trim() != 'null') {
      return value.trim();
    }
    if (value is Map) {
      final nested = _idAny(Map<String, dynamic>.from(value), ['tenantId', 'companyId', 'id']);
      if (nested.isNotEmpty) return nested;
    }
  }
  return '';
}

int _intAny(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

int _firstPositive(List<int> values) {
  for (final value in values) {
    if (value > 0) return value;
  }
  return values.isEmpty ? 0 : values.first;
}

double _doubleAny(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

bool _boolAny(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value is bool) return value;
    if (value?.toString().toLowerCase() == 'true') return true;
  }
  return false;
}

DateTime? _dateAny(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final parsed = DateTime.tryParse(item[key]?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

class DashboardScreen extends ConsumerWidget {
  final DashboardScope scope;

  const DashboardScreen({
    super.key,
    this.scope = DashboardScope.general,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final perms = ref.watch(permissionsProvider);
    final data = ref.watch(dashboardDataProvider);
    final username = (auth.username?.trim().isNotEmpty ?? false) ? auth.username!.trim() : 'Usuario';
    void refreshDashboard() {
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(productDashboardDetailsProvider(ref.read(dashboardPeriodProvider(DashboardScope.products))));
      ref.invalidate(salesDashboardDetailsProvider(ref.read(dashboardPeriodProvider(DashboardScope.sales))));
      ref.invalidate(marketingDashboardDetailsProvider(ref.read(dashboardPeriodProvider(DashboardScope.marketing))));
      ref.invalidate(warehouseDashboardDetailsProvider(ref.read(dashboardPeriodProvider(DashboardScope.warehouse))));
    }

    return AppPageScaffold(
      title: _dashboardTitle(scope),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: refreshDashboard,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => refreshDashboard(),
        child: data.when(
          data: (value) => _DashboardContent(
            data: value,
            username: username,
            permissions: perms,
            scope: scope,
          ),
          loading: () => const _DashboardLoading(),
          error: (_, __) => _DashboardContent(
            data: const DashboardData(
              products: 0,
              activeProducts: 0,
              draftProducts: 0,
              featuredProducts: 0,
              quotes: 0,
              quoteDrafts: 0,
              quoteSent: 0,
              quoteWon: 0,
              quoteAmount: 0,
              leads: 0,
              featured: 0,
              campaigns: 0,
              coupons: 0,
              sellers: 0,
              people: 0,
              users: 0,
              warehouses: 0,
              stockRows: 0,
              apiRequests: 0,
              api2xx: 0,
              apiErrors: 0,
              apiP95Ms: 0,
              apiAvgMs: 0,
              services: [],
              traces: [],
              recentQuotes: [],
              productsById: {},
            ),
            username: username,
            permissions: perms,
            scope: scope,
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final String username;
  final PermissionsService permissions;
  final DashboardScope scope;

  const _DashboardContent({
    required this.data,
    required this.username,
    required this.permissions,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    final modules = _modules(permissions);
    final cards = _dashboardCards(permissions);
    final visibleDashboards = cards.where((item) => item.visible).toList();
    if (scope == DashboardScope.products) {
      return _ModuleDashboardShell(
        child: _ProductsDashboardContent(data: data),
      );
    }
    if (scope == DashboardScope.sales) {
      return _ModuleDashboardShell(
        child: _SalesDashboardContent(data: data),
      );
    }
    if (scope == DashboardScope.marketing) {
      return _ModuleDashboardShell(
        child: _MarketingDashboardContent(data: data),
      );
    }
    if (scope == DashboardScope.warehouse) {
      return _ModuleDashboardShell(
        child: _WarehouseDashboardContent(data: data),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _HeroHeader(username: username),
        const SizedBox(height: 14),
        _SectionTitle('Dashboards'),
        const SizedBox(height: 10),
        _DashboardShortcutGrid(cards: visibleDashboards),
        const SizedBox(height: 18),
        _SectionTitle('Resumen operativo'),
        const SizedBox(height: 10),
        _KpiGrid(cards: [
          _KpiData('Productos', _n(data.products), 'Activos ${data.activeProducts} · Borrador ${data.draftProducts}', Icons.inventory_2_rounded, const Color(0xFF0EA5E9)),
          _KpiData('Cotizaciones', _n(data.quotes), 'Pendientes ${data.quoteDrafts + data.quoteSent} · Ganadas ${data.quoteWon}', Icons.request_quote_rounded, const Color(0xFF00A676)),
          _KpiData('Marketing', _n(data.campaigns), 'Leads ${data.leads} · cupones ${data.coupons}', Icons.campaign_rounded, const Color(0xFFFF5A1F)),
          _KpiData('Depósito', _n(data.stockRows), 'Stock · depósitos ${data.warehouses}', Icons.warehouse_rounded, const Color(0xFF6554F0)),
        ]),
        const SizedBox(height: 18),
        _SectionTitle('Actividad API'),
        const SizedBox(height: 10),
        _ApiPanel(data: data),
        const SizedBox(height: 18),
        _SectionTitle('Módulos'),
        const SizedBox(height: 10),
        _ModuleGrid(modules: modules),
        const SizedBox(height: 18),
        if (data.recentQuotes.isNotEmpty) ...[
          _SectionTitle('Últimas cotizaciones'),
          const SizedBox(height: 10),
          ...data.recentQuotes.map((quote) => _QuoteTile(quote: quote)),
          const SizedBox(height: 18),
        ],
        if (data.traces.isNotEmpty) ...[
          _SectionTitle('Última actividad'),
          const SizedBox(height: 10),
          ...data.traces.map((trace) => _TraceTile(trace: trace)),
        ],
      ],
    );
  }
}

List<_ModuleData> _modules(PermissionsService perms) => [
  _ModuleData('Productos', 'Artículos, publicación y carga', '/products', Icons.inventory_2_rounded, const Color(0xFF0EA5E9), perms.canAccessRoute('/products')),
  _ModuleData('Importación', 'Carga masiva operativa', '/products/import', Icons.upload_file_rounded, const Color(0xFF2563EB), perms.canAccessRoute('/products/import')),
  _ModuleData('Cotizaciones', 'Solicitud, QR y estados', '/sales/quotes', Icons.request_quote_rounded, const Color(0xFF00A676), perms.canAccessRoute('/sales/quotes')),
  _ModuleData('Depósito', 'Stock y movimientos', '/warehouse/stock', Icons.warehouse_rounded, const Color(0xFF6554F0), perms.canAccessRoute('/warehouse/stock')),
  _ModuleData('Campañas', 'Acciones y medición', '/marketing/campaigns', Icons.campaign_rounded, const Color(0xFFFF5A1F), perms.canAccessRoute('/marketing/campaigns')),
  _ModuleData('Cupones', 'Promos comerciales', '/marketing/coupons', Icons.confirmation_number_rounded, const Color(0xFFDB2777), perms.canAccessRoute('/marketing/coupons')),
  _ModuleData('Leads', 'Capturas comerciales', '/marketing/leads', Icons.leaderboard_rounded, const Color(0xFFF97316), perms.canAccessRoute('/marketing/leads')),
  _ModuleData('Usuarios', 'Roles y accesos', '/iam/users', Icons.people_rounded, const Color(0xFF0F172A), perms.canAccessRoute('/iam/users')),
  _ModuleData('Sellers', 'Datos comerciales', '/organization/sellers', Icons.storefront_rounded, const Color(0xFF0891B2), perms.canAccessRoute('/organization/sellers')),
  _ModuleData('Personas', 'Contactos diarios', '/people', Icons.badge_rounded, const Color(0xFFDB2777), perms.canAccessRoute('/people')),
].where((item) => item.visible).toList();

String _dashboardTitle(DashboardScope scope) {
  switch (scope) {
    case DashboardScope.products:
      return 'Dashboard Productos';
    case DashboardScope.sales:
      return 'Dashboard Ventas';
    case DashboardScope.marketing:
      return 'Dashboard Marketing';
    case DashboardScope.warehouse:
      return 'Dashboard Almacenes';
    case DashboardScope.general:
      return 'Dashboard';
  }
}

List<_ModuleData> _dashboardCards(PermissionsService perms) => [
      _ModuleData(
        'General',
        'Pulso operativo',
        '/dashboard',
        Icons.dashboard_rounded,
        const Color(0xFF0F172A),
        true,
      ),
      _ModuleData(
        'Productos',
        'Catálogo y publicación',
        '/dashboard/products',
        Icons.inventory_2_rounded,
        const Color(0xFF0EA5E9),
        perms.canAccessRoute('/dashboard/products'),
      ),
      _ModuleData(
        'Ventas',
        'Cotizaciones y pipeline',
        '/dashboard/sales',
        Icons.request_quote_rounded,
        const Color(0xFF00A676),
        perms.canAccessRoute('/dashboard/sales'),
      ),
      _ModuleData(
        'Marketing',
        'Campañas y señales',
        '/dashboard/marketing',
        Icons.campaign_rounded,
        const Color(0xFFFF5A1F),
        perms.canAccessRoute('/dashboard/marketing'),
      ),
      _ModuleData(
        'Almacenes',
        'Stock y movimientos',
        '/dashboard/warehouse',
        Icons.warehouse_rounded,
        const Color(0xFF6554F0),
        perms.canAccessRoute('/dashboard/warehouse'),
      ),
    ];

class _ModuleDashboardShell extends StatelessWidget {
  final Widget child;

  const _ModuleDashboardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [child],
    );
  }
}

class _DashboardShortcutGrid extends StatelessWidget {
  final List<_ModuleData> cards;

  const _DashboardShortcutGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (_, index) => _CompactRouteCard(module: cards[index]),
    );
  }
}

class _CompactRouteCard extends StatelessWidget {
  final _ModuleData module;

  const _CompactRouteCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(module.route),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: module.color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductsDashboardContent extends ConsumerWidget {
  final DashboardData data;

  const _ProductsDashboardContent({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardPeriodProvider(DashboardScope.products));
    final details = ref.watch(productDashboardDetailsProvider(period));
    Widget buildContent(ProductDashboardDetails metrics) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardIntro(
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF0EA5E9),
          title: 'Catálogo',
          subtitle: 'Publicación, calidad de ficha y señales comerciales.',
        ),
        const SizedBox(height: 12),
        _PeriodSelector(
          value: period,
          onChanged: (value) => ref
              .read(dashboardPeriodProvider(DashboardScope.products).notifier)
              .state = value,
        ),
        const SizedBox(height: 14),
        _KpiGrid(cards: [
          _KpiData('Productos', _n(metrics.products), 'Total cargado · ${_periodLabel(period)}', Icons.inventory_2_rounded, const Color(0xFF0EA5E9)),
          _KpiData('Activos', _n(metrics.activeProducts), 'Disponibles para operar', Icons.check_circle_rounded, const Color(0xFF00A676)),
          _KpiData('Borradores', _n(metrics.draftProducts), 'Pendientes de publicar', Icons.edit_note_rounded, const Color(0xFFF59E0B)),
          _KpiData('Destacados', _n(metrics.featuredProducts), 'Visibles como destacados', Icons.sell_rounded, const Color(0xFF7C3AED)),
        ]),
        const SizedBox(height: 16),
        _InsightPanel(
          title: 'Calidad de ficha',
          subtitle: 'Estado general de carga del catálogo.',
          rows: [
            _InsightRow('Activos', metrics.activeProducts, math.max(1, metrics.products), const Color(0xFF00A676)),
            _InsightRow('Borradores', metrics.draftProducts, math.max(1, metrics.products), const Color(0xFFF59E0B)),
            _InsightRow('Destacados', metrics.featuredProducts, math.max(1, metrics.products), const Color(0xFF7C3AED)),
          ],
        ),
      ],
    );

    return details.when(
      data: buildContent,
      loading: () => buildContent(ProductDashboardDetails(
        products: data.products,
        activeProducts: data.activeProducts,
        draftProducts: data.draftProducts,
        featuredProducts: data.featuredProducts,
      )),
      error: (_, __) => buildContent(ProductDashboardDetails(
        products: data.products,
        activeProducts: data.activeProducts,
        draftProducts: data.draftProducts,
        featuredProducts: data.featuredProducts,
      )),
    );
  }
}

class _MarketingDashboardContent extends ConsumerWidget {
  final DashboardData data;

  const _MarketingDashboardContent({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardPeriodProvider(DashboardScope.marketing));
    final details = ref.watch(marketingDashboardDetailsProvider(period));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardIntro(
          icon: Icons.campaign_rounded,
          color: const Color(0xFFFF5A1F),
          title: 'Marketing',
          subtitle: 'Campañas, intención comercial y señales del catálogo.',
        ),
        const SizedBox(height: 12),
        _PeriodSelector(
          value: period,
          onChanged: (value) => ref
              .read(dashboardPeriodProvider(DashboardScope.marketing).notifier)
              .state = value,
        ),
        const SizedBox(height: 14),
        details.when(
          data: (value) => _KpiGrid(cards: [
            _KpiData('Campañas', _n(data.campaigns), 'Configuradas', Icons.campaign_rounded, const Color(0xFFFF5A1F)),
            _KpiData('Eventos', _n(value.events), _periodLabel(period), Icons.leaderboard_rounded, const Color(0xFF2563EB)),
            _KpiData('Leads', _n(value.leads), 'Capturas comerciales', Icons.person_add_alt_1_rounded, const Color(0xFF00A676)),
            _KpiData('Conversiones', _n(value.conversions), 'Cierre medido', Icons.trending_up_rounded, const Color(0xFF0F172A)),
          ]),
          loading: () => _KpiGrid(cards: [
            _KpiData('Campañas', _n(data.campaigns), 'Configuradas', Icons.campaign_rounded, const Color(0xFFFF5A1F)),
            _KpiData('Eventos', '...', _periodLabel(period), Icons.leaderboard_rounded, const Color(0xFF2563EB)),
            _KpiData('Leads', '...', 'Capturas comerciales', Icons.person_add_alt_1_rounded, const Color(0xFF00A676)),
            _KpiData('Conversiones', '...', 'Cierre medido', Icons.trending_up_rounded, const Color(0xFF0F172A)),
          ]),
          error: (_, __) => _KpiGrid(cards: [
            _KpiData('Campañas', _n(data.campaigns), 'Configuradas', Icons.campaign_rounded, const Color(0xFFFF5A1F)),
            _KpiData('Leads', _n(data.leads), 'Capturas comerciales', Icons.leaderboard_rounded, const Color(0xFF2563EB)),
            _KpiData('Cupones', _n(data.coupons), 'Promos disponibles', Icons.confirmation_number_rounded, const Color(0xFFDB2777)),
            _KpiData('Destacados', _n(data.featured), 'Productos destacados', Icons.star_rounded, const Color(0xFF7C3AED)),
          ]),
        ),
        const SizedBox(height: 16),
        details.when(
          data: (value) => Column(
            children: [
              _MarketingFunnelPanel(metrics: value.funnel),
              const SizedBox(height: 16),
              _MarketingTopProductsPanel(
                products: value.topProducts,
                lookup: data.productsById,
              ),
            ],
          ),
          loading: () => const _DashboardLoadingBlock(height: 420),
          error: (_, __) => _InsightPanel(
            title: 'Funnel comercial',
            subtitle: 'No se pudo cargar el reporting del período.',
            rows: [
              _InsightRow('Presupuesto', 0, 1, const Color(0xFF00A676)),
              _InsightRow('Consultar stock', 0, 1, const Color(0xFFF59E0B)),
              _InsightRow('Compra mayorista', 0, 1, const Color(0xFFFF5A1F)),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarehouseDashboardContent extends ConsumerWidget {
  final DashboardData data;

  const _WarehouseDashboardContent({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardPeriodProvider(DashboardScope.warehouse));
    final details = ref.watch(warehouseDashboardDetailsProvider(period));
    Widget buildContent(WarehouseDashboardDetails metrics) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardIntro(
          icon: Icons.warehouse_rounded,
          color: const Color(0xFF6554F0),
          title: 'Almacenes',
          subtitle: 'Cobertura de stock y operación por depósito.',
        ),
        const SizedBox(height: 12),
        _PeriodSelector(
          value: period,
          onChanged: (value) => ref
              .read(dashboardPeriodProvider(DashboardScope.warehouse).notifier)
              .state = value,
        ),
        const SizedBox(height: 14),
        _KpiGrid(cards: [
          _KpiData('Depósitos', _n(metrics.warehouses), 'Configurados · ${_periodLabel(period)}', Icons.warehouse_rounded, const Color(0xFF6554F0)),
          _KpiData('Stock', _n(metrics.stockRows), 'Filas de stock', Icons.inventory_rounded, const Color(0xFF00A676)),
          _KpiData('Productos', _n(data.products), 'Catálogo base', Icons.inventory_2_rounded, const Color(0xFF0EA5E9)),
          _KpiData('Sellers', _n(data.sellers), 'Operación asociada', Icons.storefront_rounded, const Color(0xFF0891B2)),
        ]),
        const SizedBox(height: 16),
        _InsightPanel(
          title: 'Salud operativa',
          subtitle: 'Base de control para cobertura y movimientos.',
          rows: [
            _InsightRow('Stock registrado', metrics.stockRows, math.max(1, data.products), const Color(0xFF00A676)),
            _InsightRow('Depósitos activos', metrics.activeWarehouses, math.max(1, metrics.warehouses), const Color(0xFF6554F0)),
            _InsightRow('Movimientos', metrics.movements, math.max(1, metrics.movements), const Color(0xFFF59E0B)),
            _InsightRow('Sellers', data.sellers, math.max(1, data.sellers), const Color(0xFF0891B2)),
          ],
        ),
      ],
    );

    return details.when(
      data: buildContent,
      loading: () => buildContent(WarehouseDashboardDetails(
        warehouses: data.warehouses,
        activeWarehouses: data.warehouses,
        stockRows: data.stockRows,
        movements: 0,
      )),
      error: (_, __) => buildContent(WarehouseDashboardDetails(
        warehouses: data.warehouses,
        activeWarehouses: data.warehouses,
        stockRows: data.stockRows,
        movements: 0,
      )),
    );
  }
}

class _SalesDashboardContent extends ConsumerWidget {
  final DashboardData data;

  const _SalesDashboardContent({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardPeriodProvider(DashboardScope.sales));
    final details = ref.watch(salesDashboardDetailsProvider(period));
    Widget buildContent(SalesDashboardDetails metrics) {
      final pending = metrics.draft + metrics.sent;
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardIntro(
          icon: Icons.request_quote_rounded,
          color: const Color(0xFF00A676),
          title: 'Ventas',
          subtitle: 'Cotizaciones, pipeline y pendientes por período.',
        ),
        const SizedBox(height: 12),
        _PeriodSelector(
          value: period,
          onChanged: (value) => ref
              .read(dashboardPeriodProvider(DashboardScope.sales).notifier)
              .state = value,
        ),
        const SizedBox(height: 14),
        _KpiGrid(cards: [
          _KpiData('Cotizaciones', _n(metrics.quotes), _periodLabel(period), Icons.receipt_long_rounded, const Color(0xFF0EA5E9)),
          _KpiData('Pendientes', _n(pending), 'Borrador + enviada', Icons.notifications_active_rounded, const Color(0xFFF59E0B)),
          _KpiData('Ganadas', _n(metrics.won), 'Cerradas positivas', Icons.shopping_cart_checkout_rounded, const Color(0xFF00A676)),
          _KpiData('Monto', _money(metrics.amount), 'Visible del período', Icons.payments_rounded, const Color(0xFF0F172A)),
        ]),
        const SizedBox(height: 16),
        _InsightPanel(
          title: 'Pipeline por estado',
          subtitle: 'Solicitudes y avance comercial del período.',
          rows: [
            _InsightRow('Borrador', metrics.draft, math.max(1, metrics.quotes), const Color(0xFF94A3B8)),
            _InsightRow('Enviadas', metrics.sent, math.max(1, metrics.quotes), const Color(0xFF0EA5E9)),
            _InsightRow('Ganadas', metrics.won, math.max(1, metrics.quotes), const Color(0xFF00A676)),
          ],
        ),
        const SizedBox(height: 16),
        _RecentQuotePanel(quotes: metrics.recentQuotes),
      ],
    );
    }

    return details.when(
      data: buildContent,
      loading: () {
        final quotes = _quotesForPeriod(data.recentQuotes, period);
        return buildContent(SalesDashboardDetails(
          quotes: quotes.length,
          draft: quotes.where((quote) => quote.status == 'DRAFT').length,
          sent: quotes.where((quote) => quote.status == 'SENT').length,
          won: quotes.where((quote) => quote.status == 'WON').length,
          amount: quotes.fold<double>(0, (sum, quote) => sum + quote.amount),
          recentQuotes: quotes,
        ));
      },
      error: (_, __) {
        final quotes = _quotesForPeriod(data.recentQuotes, period);
        return buildContent(SalesDashboardDetails(
          quotes: quotes.length,
          draft: quotes.where((quote) => quote.status == 'DRAFT').length,
          sent: quotes.where((quote) => quote.status == 'SENT').length,
          won: quotes.where((quote) => quote.status == 'WON').length,
          amount: quotes.fold<double>(0, (sum, quote) => sum + quote.amount),
          recentQuotes: quotes,
        ));
      },
    );
  }
}

class _DashboardIntro extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _DashboardIntro({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final DashboardPeriod value;
  final ValueChanged<DashboardPeriod> onChanged;

  const _PeriodSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: DashboardPeriod.values.map((period) {
          final selected = period == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  _periodLabel(period),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InsightRow {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _InsightRow(this.label, this.value, this.total, this.color);
}

class _InsightPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_InsightRow> rows;

  const _InsightPanel({
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => _ProgressLine(
                label: row.label,
                value: row.value,
                total: math.max(1, row.total),
                color: row.color,
              )),
        ],
      ),
    );
  }
}

class _MarketingFunnelPanel extends StatelessWidget {
  final List<MarketingFunnelMetric> metrics;

  const _MarketingFunnelPanel({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, metrics.fold<int>(0, (sum, item) => sum + item.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Funnel comercial'.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FFF5),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'INTENCIÓN',
                  style: TextStyle(
                    color: Color(0xFF00A676),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...metrics.map((metric) => _FunnelMetricCard(metric: metric, total: total)),
        ],
      ),
    );
  }
}

class _FunnelMetricCard extends StatelessWidget {
  final MarketingFunnelMetric metric;
  final int total;

  const _FunnelMetricCard({
    required this.metric,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metric.label.toUpperCase(), style: _eyebrow()),
                    const SizedBox(height: 4),
                    Text(
                      _n(metric.value),
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: metric.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: metric.color.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(metric.icon, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (metric.value / total).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.surfaceVariant,
              color: metric.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketingTopProductsPanel extends StatelessWidget {
  final List<MarketingProductMetric> products;
  final Map<String, ProductLookup> lookup;

  const _MarketingTopProductsPanel({
    required this.products,
    required this.lookup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top productos por impresiones'.toUpperCase(),
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ranking por vistas de producto y exposición en destacados.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Sin movimiento para mostrar',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            ...products.asMap().entries.map((entry) {
              final maxImpressions = products.fold<int>(1, (max, item) => math.max(max, item.impressions));
              final product = entry.value;
              final info = lookup[product.productId];
              return _MarketingProductTile(
                rank: entry.key + 1,
                product: product,
                name: info?.name ?? 'Producto',
                sku: info?.sku ?? '',
                maxImpressions: maxImpressions,
              );
            }),
        ],
      ),
    );
  }
}

class _MarketingProductTile extends StatelessWidget {
  final int rank;
  final MarketingProductMetric product;
  final String name;
  final String sku;
  final int maxImpressions;

  const _MarketingProductTile({
    required this.rank,
    required this.product,
    required this.name,
    required this.sku,
    required this.maxImpressions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900)),
                    if (sku.isNotEmpty)
                      Text(sku, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_n(product.impressions), style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('impresiones', style: _eyebrow()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (product.impressions / math.max(1, maxImpressions)).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TinyMetric('Vistas', product.views),
              _TinyMetric('Likes', product.likes),
              _TinyMetric('Intento', product.quoteRequests),
              _TinyMetric('Dest.', product.featuredViews),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyMetric extends StatelessWidget {
  final String label;
  final int value;

  const _TinyMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_n(value)} $label',
      style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900),
    );
  }
}

class _RecentQuotePanel extends StatelessWidget {
  final List<RecentQuote> quotes;

  const _RecentQuotePanel({required this.quotes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pendientes para accionar',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Solicitudes recientes del período seleccionado.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (quotes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay cotizaciones para este período',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            ...quotes.take(5).map((quote) => _QuoteTile(quote: quote)),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String username;
  const _HeroHeader({required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hola, ${_friendlyFirstName(username)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Centro operativo',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Productos, ventas, marketing, depósito y seguridad en una sola lectura.',
              style: TextStyle(color: Colors.white70, height: 1.35, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final List<_KpiData> cards;
  const _KpiGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (_, index) => _KpiCard(data: cards[index]),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.detail, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: data.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _eyebrow()),
                const SizedBox(height: 3),
                Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.ink, fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 1),
                Text(data.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesPanel extends StatelessWidget {
  final DashboardData data;
  const _SalesPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final pending = data.quoteDrafts + data.quoteSent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _MiniBlock('Monto visible', _money(data.quoteAmount), Icons.receipt_long_rounded, const Color(0xFF0F172A))),
              const SizedBox(width: 10),
              Expanded(child: _MiniBlock('Pendientes', _n(pending), Icons.notifications_active_rounded, const Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressLine(label: 'Borrador', value: data.quoteDrafts, total: math.max(1, data.quotes), color: const Color(0xFF94A3B8)),
          _ProgressLine(label: 'Enviadas', value: data.quoteSent, total: math.max(1, data.quotes), color: const Color(0xFF0EA5E9)),
          _ProgressLine(label: 'Ganadas', value: data.quoteWon, total: math.max(1, data.quotes), color: const Color(0xFF00A676)),
        ],
      ),
    );
  }
}

class _ApiPanel extends StatelessWidget {
  final DashboardData data;
  const _ApiPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MiniBlock('Requests', _n(data.apiRequests), Icons.monitor_heart_rounded, const Color(0xFF2563EB))),
              const SizedBox(width: 10),
              Expanded(child: _MiniBlock('P95', _duration(data.apiP95Ms), Icons.speed_rounded, const Color(0xFF7C3AED))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MiniBlock('2xx', '${data.api2xx}', Icons.check_circle_rounded, const Color(0xFF00A676))),
              const SizedBox(width: 10),
              Expanded(child: _MiniBlock('Errores', '${data.apiErrors}', Icons.error_outline_rounded, const Color(0xFFEF4444))),
            ],
          ),
          if (data.services.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Servicios más usados', style: _eyebrow()),
            const SizedBox(height: 8),
            ...data.services.map((service) => _ServiceRow(service: service)),
          ],
        ],
      ),
    );
  }
}

class _MiniBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniBlock(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(label, style: _eyebrow()),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _ProgressLine({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final percent = (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('$value', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final ServiceStat service;
  const _ServiceRow({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(service.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900))),
              Text('${service.requests} req', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${service.ok} OK · ${service.errors} errores · P95 ${_duration(service.p95Ms)} · acumulado ${_duration(service.totalMs)}', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  final List<_ModuleData> modules;
  const _ModuleGrid({required this.modules});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (_, index) => _ModuleCard(module: modules[index]),
    );
  }
}

class _ModuleData {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final Color color;
  final bool visible;
  const _ModuleData(this.title, this.subtitle, this.route, this.icon, this.color, this.visible);
}

class _ModuleCard extends StatelessWidget {
  final _ModuleData module;
  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(module.route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: module.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(module.icon, color: module.color, size: 21),
              ),
              const Spacer(),
              Text(module.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(module.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.25)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  final RecentQuote quote;
  const _QuoteTile({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.request_quote_rounded, color: Color(0xFF00A676)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quote.number, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900)),
                Text('${quote.customer}${quote.createdAt == null ? '' : ' · ${DateFormat('dd/MM HH:mm').format(quote.createdAt!)}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(quote.status, style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
              Text(_money(quote.amount), style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TraceTile extends StatelessWidget {
  final RecentTrace trace;
  const _TraceTile({required this.trace});

  @override
  Widget build(BuildContext context) {
    final statusColor = trace.status >= 400 ? const Color(0xFFEF4444) : const Color(0xFF00A676);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 56,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('${trace.status}', style: TextStyle(color: statusColor, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trace.method} · ${trace.service}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Peso ${_bytes(trace.payloadBytes)}', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Text(_duration(trace.durationMs), style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DashboardLoadingBlock extends StatelessWidget {
  final double height;

  const _DashboardLoadingBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Container(height: 134, decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(26))),
        const SizedBox(height: 18),
        ...List.generate(6, (_) => Container(
          height: 112,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(20)),
        )),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.border),
  boxShadow: const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 5)),
  ],
);

TextStyle _eyebrow() => TextStyle(
  color: AppColors.textMuted,
  fontSize: 10,
  fontWeight: FontWeight.w900,
  letterSpacing: 1,
);

String _n(int value) => NumberFormat.decimalPattern('es_AR').format(value);

String _money(double value) => NumberFormat.currency(locale: 'es_AR', symbol: r'$ ', decimalDigits: 0).format(value);

String _duration(int ms) {
  if (ms <= 0) return '0 ms';
  if (ms >= 300000) return '${(ms / 60000).toStringAsFixed(1)} min';
  if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(1)} s';
  return '$ms ms';
}

String _bytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String _periodCode(DashboardPeriod period) {
  switch (period) {
    case DashboardPeriod.today:
      return 'today';
    case DashboardPeriod.threeDays:
      return '3d';
    case DashboardPeriod.sevenDays:
      return 'week';
    case DashboardPeriod.all:
      return 'all';
  }
}

Map<String, dynamic> _quotePeriodParams(DashboardPeriod period) {
  if (period == DashboardPeriod.all) return const {};
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  late final DateTime startDate;
  switch (period) {
    case DashboardPeriod.today:
      startDate = DateTime(now.year, now.month, now.day);
      break;
    case DashboardPeriod.threeDays:
      startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2));
      break;
    case DashboardPeriod.sevenDays:
      startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      break;
    case DashboardPeriod.all:
      startDate = DateTime.fromMillisecondsSinceEpoch(0);
      break;
  }
  return {
    'createdFrom': _payloadDateTime(startDate),
    'createdTo': _payloadDateTime(end),
  };
}

String _payloadDateTime(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final h = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  final s = value.second.toString().padLeft(2, '0');
  return '$y-$m-${d}T$h:$min:$s';
}

String _periodLabel(DashboardPeriod period) {
  switch (period) {
    case DashboardPeriod.today:
      return 'Hoy';
    case DashboardPeriod.threeDays:
      return '3 días';
    case DashboardPeriod.sevenDays:
      return '7 días';
    case DashboardPeriod.all:
      return 'Todo';
  }
}

List<RecentQuote> _quotesForPeriod(
  List<RecentQuote> quotes,
  DashboardPeriod period,
) {
  if (period == DashboardPeriod.all) return quotes;
  final now = DateTime.now();
  late final DateTime start;
  switch (period) {
    case DashboardPeriod.today:
      start = DateTime(now.year, now.month, now.day);
      break;
    case DashboardPeriod.threeDays:
      start = now.subtract(const Duration(days: 3));
      break;
    case DashboardPeriod.sevenDays:
      start = now.subtract(const Duration(days: 7));
      break;
    case DashboardPeriod.all:
      start = DateTime.fromMillisecondsSinceEpoch(0);
      break;
  }
  return quotes.where((quote) {
    final createdAt = quote.createdAt;
    return createdAt != null && createdAt.isAfter(start);
  }).toList();
}

String _friendlyFirstName(String username) {
  final normalized = username.trim();
  if (normalized.isEmpty) return 'Usuario';
  final base = normalized.contains('@')
      ? normalized.split('@').first
      : normalized.split(RegExp(r'\s+')).first;
  if (base.isEmpty) return 'Usuario';
  return base[0].toUpperCase() + base.substring(1);
}
