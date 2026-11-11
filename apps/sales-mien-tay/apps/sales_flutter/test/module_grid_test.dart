import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/main.dart';

void main() {
  const names = [
    'Tổng quan','Khách hàng / Điểm bán','Khảo sát','Target','Dự kiến',
    'Lịch trình','Hỗ trợ','Chính sách','Yêu cầu','Báo cáo tháng',
    'Danh mục SKU','Tra tồn','Ra đơn',
  ];
  for (final width in [320.0, 360.0, 390.0, 780.0, 1280.0, 1440.0]) {
    testWidgets('all 12 shortcuts fit and navigate at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <int>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(18),
          child: SalesModuleGrid(sections: names,
            icons: List.filled(names.length, Icons.grid_view_outlined),
            onSelect: selected.add)),
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(InkWell), findsNWidgets(12));
      final delegate = tester.widget<GridView>(find.byType(GridView)).gridDelegate
        as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, width < 350 ? 2 : width < 668 ? 3
        : width < 1036 ? 4 : 6);
      await tester.ensureVisible(find.byKey(const ValueKey('module-grid-12')));
      await tester.tap(find.byKey(const ValueKey('module-grid-12')));
      expect(selected, [12]);
      expect(tester.takeException(), isNull);
    });
  }
}
