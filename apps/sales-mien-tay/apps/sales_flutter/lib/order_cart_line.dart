import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A row keeps its quantity editor bound to line_id, even after removal/undo.
class OrderCartLine extends StatefulWidget {
  final int number;
  final Map<String, dynamic> line;
  final String stockMessage;
  final bool editable;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  const OrderCartLine({
    super.key,
    required this.number,
    required this.line,
    required this.stockMessage,
    required this.editable,
    required this.onQuantity,
    required this.onRemove,
  });

  @override
  State<OrderCartLine> createState() => _OrderCartLineState();
}

class _OrderCartLineState extends State<OrderCartLine> {
  static const maxQuantity = 100000000;
  late final TextEditingController controller;
  late final FocusNode focus;
  bool invalid = false;

  String get lineId => widget.line['line_id']?.toString() ?? '';
  int get quantity => int.tryParse('${widget.line['quantity']}') ?? 1;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: '$quantity');
    focus = FocusNode()..addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant OrderCartLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!focus.hasFocus && controller.text != '$quantity') {
      controller.text = '$quantity';
      invalid = false;
    }
  }

  void _focusChanged() {
    if (!focus.hasFocus) _finishInput();
  }

  void _finishInput() {
    if (!mounted) return;
    final parsed = int.tryParse(controller.text);
    if (parsed == null || parsed < 1 || parsed > maxQuantity) {
      setState(() => invalid = false);
      controller.text = '$quantity';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Số lượng từ 1 đến 100.000.000.')),
      );
      return;
    }
    if (parsed != quantity) widget.onQuantity(parsed);
    if (invalid) setState(() => invalid = false);
  }

  void _edit(String value) {
    final parsed = int.tryParse(value);
    final valid = parsed != null && parsed >= 1 && parsed <= maxQuantity;
    if (invalid == valid) setState(() => invalid = !valid);
    if (valid && parsed != quantity) widget.onQuantity(parsed);
  }

  void _adjust(int change) {
    final next = quantity + change;
    if (next < 1 || next > maxQuantity) return;
    focus.unfocus();
    controller.text = '$next';
    if (invalid) setState(() => invalid = false);
    widget.onQuantity(next);
  }

  @override
  void dispose() {
    focus.removeListener(_focusChanged);
    focus.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.number.toString().padLeft(2, '0');
    final code = widget.line['company_code']?.toString() ?? '—';
    final name = widget.line['name']?.toString() ?? 'Sản phẩm';
    final unit = widget.line['unit']?.toString() ?? '—';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Text(label, style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w700,
              )),
            ),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$code · $name', maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('ĐVT: $unit', style: theme.textTheme.bodySmall),
              ],
            )),
            if (widget.editable) IconButton(
              key: ValueKey('cart-delete-$lineId'),
              tooltip: 'Bỏ dòng $label',
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.onRemove,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Expanded(child: Text(widget.stockMessage,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.stockMessage.startsWith('Thiếu tồn')
                    ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
              ))),
            const SizedBox(width: 6),
            if (widget.editable) ...[
              IconButton(
                key: ValueKey('cart-minus-$lineId'),
                tooltip: 'Giảm số lượng dòng $label',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: quantity <= 1 ? null : () => _adjust(-1),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
              SizedBox(width: 68, child: TextField(
                key: ValueKey('cart-quantity-$lineId'),
                controller: controller,
                focusNode: focus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                onChanged: _edit,
                onSubmitted: (_) => _finishInput(),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'SL',
                  errorText: invalid ? '1–100M' : null,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                ),
              )),
              IconButton(
                key: ValueKey('cart-plus-$lineId'),
                tooltip: 'Tăng số lượng dòng $label',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: quantity >= maxQuantity ? null : () => _adjust(1),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
            ] else Text('SL $quantity', style: theme.textTheme.titleMedium),
          ]),
        ]),
      ),
    );
  }
}
