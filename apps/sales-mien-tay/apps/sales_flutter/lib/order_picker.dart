import 'dart:async';
import 'package:flutter/material.dart';
import 'actuals.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'stock.dart';

/// Company codes remain strings, including leading zeros.
bool orderPickerMatches(Map<String, dynamic> row, String query, {required bool products}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final fields = products
      ? ['name', 'company_code', 'sku', 'brand', 'category']
      : ['name', 'customer_code', 'export_code', 'province', 'district'];
  return fields.any((field) =>
      (row[field]?.toString() ?? '').toLowerCase().contains(q));
}

List<Map<String, dynamic>> _pickerRows(Object? data) =>
    (data as List? ?? const [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

bool _stockIsOld(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ||
      DateTime.now().toUtc().difference(date.toUtc()) > const Duration(hours: 24);
}

/// Separate picker component; the existing order/cart workflow stays intact.
class OrderPicker extends StatefulWidget {
  final ActualClient client;
  final OfflineQueue queue;
  final String type;
  const OrderPicker({
    super.key,
    required this.client,
    required this.queue,
    required this.type,
  });

  @override
  State<OrderPicker> createState() => _OrderPickerState();
}

class _OrderPickerState extends State<OrderPicker> {
  static const pageSize = 60;
  static const maxCacheItems = 10000;
  final search = TextEditingController();
  Timer? debounce;
  int generation = 0;
  bool busy = true, loadingMore = false, offline = false;
  bool denied = false, warming = false, completeCache = false;
  String? error, cursor;
  List<Map<String, dynamic>> rows = [], cached = [];

  bool get products => widget.type == 'products';
  String get query => search.text.trim();
  String get cacheKey => 'order-picker-${widget.type}-full-v2';
  String get endpoint => '/api/v1/orders/${widget.type}';

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    generation++;
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final saved = await widget.queue.cached(cacheKey);
      if (saved.isNotEmpty) {
        cached = _pickerRows(saved.first['items']);
        completeCache = saved.first['complete'] == true;
      }
      if (cached.isEmpty && products) {
        final stock = await widget.queue.cached(stockCacheKey);
        if (stock.isNotEmpty) {
          cached = _pickerRows(stock.first['items']);
          completeCache = stock.first['partial'] != true;
        }
      }
      if (cached.isEmpty && !products) {
        final legacy = await widget.queue.cached('order-picker-customers');
        if (legacy.isNotEmpty) cached = _pickerRows(legacy.first['items']);
      }
    } catch (_) {
      // A corrupt local cache must not block a fresh server query.
    }
    if (!mounted) return;
    setState(() => rows = _localMatches(query));
    await _fetch();
  }

  List<Map<String, dynamic>> _localMatches(String term) =>
      cached.where((row) => orderPickerMatches(row, term, products: products)).toList();

  void _onChanged(String _) {
    debounce?.cancel();
    final expected = ++generation;
    setState(() {
      rows = _localMatches(query);
      error = null;
      cursor = null;
      offline = false;
      busy = true;
      loadingMore = false;
    });
    debounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(_fetch(expected: expected));
    });
  }

  Future<void> _fetch({int? expected, bool more = false}) async {
    if (!mounted || denied || (more && (cursor == null || loadingMore || busy))) return;
    final current = expected ?? (more ? generation : ++generation);
    final term = query;
    final after = more ? cursor : null;
    setState(() {
      if (more) {
        loadingMore = true;
      } else {
        busy = true;
      }
      error = null;
    });
    try {
      final parameters = <String, String>{'q': term, 'limit': '$pageSize'};
      if (products && after != null) parameters['after'] = after;
      final response = await widget.client.get(saleParam(endpoint, parameters));
      if (!mounted || denied || current != generation || term != query) return;
      final page = _pickerRows(response['items']);
      final next = products ? response['next_cursor']?.toString() : null;
      setState(() {
        rows = more ? [...rows, ...page] : page;
        cursor = next != after ? next : null;
        offline = false;
        error = null;
      });
      // Only a complete unfiltered catalogue may replace offline data.
      if (products && !more && term.isEmpty && !warming) {
        unawaited(_warmProducts(page, next));
      } else if (!products && !more && term.isEmpty) {
        unawaited(widget.queue.cache(cacheKey, [
          {'items': page, 'complete': page.length < 100,
           'synced_at': DateTime.now().toUtc().toIso8601String()}
        ]).catchError((_) {}));
      }
    } catch (e) {
      if (!mounted || current != generation || term != query) return;
      if (e is ApiFailure && (e.status == 401 || e.status == 403)) {
        debounce?.cancel();
        generation++;
        setState(() {
          denied = true;
          cached = [];
          rows = [];
          cursor = null;
          busy = false;
          loadingMore = false;
          error = 'Quyền truy cập đã thay đổi. Vui lòng đăng nhập lại.';
        });
        unawaited(widget.queue.cache(cacheKey, []).catchError((_) {}));
      } else {
        setState(() {
          offline = true;
          cursor = null;
          if (!more) rows = _localMatches(term);
          error = cached.isEmpty
              ? 'Không có danh mục đã lưu. Cần kết nối để tìm sản phẩm.'
              : completeCache
                  ? 'Đang dùng danh mục lưu máy. Tồn sẽ kiểm lại khi xuất.'
                  : 'Đang dùng dữ liệu lưu máy, có thể chưa đủ mã.';
        });
      }
    } finally {
      if (mounted && current == generation) {
        setState(() {
          busy = false;
          loadingMore = false;
        });
      }
    }
  }

  /// Do not poison full offline catalogue with partial search/page results.
  Future<void> _warmProducts(List<Map<String, dynamic>> first, String? next) async {
    if (!products || warming || denied) return;
    warming = true;
    try {
      final all = [...first];
      var cursorToLoad = next;
      while (cursorToLoad != null && all.length < maxCacheItems) {
        final response = await widget.client.get(saleParam(endpoint, {
          'q': '',
          'limit': '100',
          'after': cursorToLoad,
        }));
        final page = _pickerRows(response['items']);
        final following = response['next_cursor']?.toString();
        if (page.isEmpty || following == cursorToLoad) {
          throw StateError('Phân trang danh mục không tiến');
        }
        all.addAll(page);
        cursorToLoad = following;
      }
      if (cursorToLoad != null || denied) return;
      await widget.queue.cache(cacheKey, [{
        'items': all,
        'complete': true,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      }]);
      if (mounted && !denied) {
        setState(() {
          cached = all;
          completeCache = true;
        });
      }
    } catch (e) {
      if (e is ApiFailure && (e.status == 401 || e.status == 403) && mounted) {
        generation++;
        setState(() {
          denied = true;
          cached = [];
          rows = [];
          cursor = null;
          busy = false;
          loadingMore = false;
          error = 'Quyền truy cập đã thay đổi. Vui lòng đăng nhập lại.';
        });
        unawaited(widget.queue.cache(cacheKey, []).catchError((_) {}));
      }
      // A failed page must never overwrite the last complete cache.
    } finally {
      warming = false;
    }
  }

  Widget _result(Map<String, dynamic> row) {
    if (!products) {
      return ListTile(
        key: ValueKey('order-customer-${row['id']}'),
        title: Text(row['name']?.toString() ?? 'Chưa có tên'),
        subtitle: Text(
          'Mã CTY: ${row['export_code'] ?? 'Chưa có'} · ${row['district'] ?? ''}, ${row['province'] ?? ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pop(context, row),
      );
    }
    final amount = row['quantity']?.toString();
    final stale = _stockIsOld(row['snapshot_at']);
    final code = row['company_code']?.toString() ?? '';
    final sku = row['sku']?.toString() ?? '';
    final brand = row['brand']?.toString() ?? '';
    final unit = row['unit']?.toString() ?? 'Chưa có ĐVT';
    return InkWell(
      key: ValueKey('order-product-$code'),
      onTap: () => Navigator.pop(context, row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$code · ${row['name'] ?? ''}',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text([if (sku.isNotEmpty) 'SKU $sku', if (brand.isNotEmpty) brand, unit].join(' · '),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ])),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount == null ? 'Chưa có tồn' : 'Tồn $amount',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              Text(amount == null ? 'Chưa cập nhật' : stale ? 'Tồn cũ' : 'Mới cập nhật',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: stale ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Icon(Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary, size: 24),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _content() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: TextField(
            key: const Key('order-picker-search'),
            controller: search,
            autofocus: false,
            maxLength: 120,
            onChanged: _onChanged,
            onSubmitted: (_) {
              debounce?.cancel();
              unawaited(_fetch());
            },
            decoration: InputDecoration(
              hintText: products ? 'Tìm mã, SKU, tên, nhãn hàng' : 'Tìm tên hoặc mã khách',
              prefixIcon: const Icon(Icons.search),
              counterText: '',
              suffixIcon: IconButton(
                tooltip: 'Xóa tìm kiếm',
                icon: const Icon(Icons.close),
                onPressed: () {
                  search.clear();
                  _onChanged('');
                },
              ),
            ),
          ),
        ),
        if (offline || error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(error ?? 'Dữ liệu lưu máy · tồn sẽ kiểm lại khi xuất.',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: rows.isEmpty && !busy
            ? Center(child: Text(denied
                ? 'Không còn quyền truy cập.'
                : 'Không tìm thấy mã phù hợp.'))
            : ListView.separated(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: rows.length + (cursor != null ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == rows.length) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(child: OutlinedButton(
                        key: const Key('order-picker-load-more'),
                        onPressed: loadingMore || busy ? null : () => unawaited(_fetch(more: true)),
                        child: Text(loadingMore ? 'Đang tải…' : 'Xem thêm sản phẩm'),
                      )),
                    );
                  }
                  return _result(rows[index]);
                },
              )),
      ]);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final heading = products ? 'Chọn sản phẩm' : 'Chọn khách hàng';
    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(heading),
            leading: IconButton(
              tooltip: 'Đóng',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(child: _content()),
        ),
      );
    }
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 680,
        height: (MediaQuery.sizeOf(context).height * .82).clamp(320.0, 660.0),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              Expanded(child: Text(heading, style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                tooltip: 'Đóng',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(child: _content()),
        ]),
      ),
    );
  }
}
