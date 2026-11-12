import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/responsive_controls.dart';
import 'package:sales_mien_tay/theme.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0, 1024.0]) {
    testWidgets('P1-H compact filters fit ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: SalesTheme.build(width: width),
        home: Scaffold(body: Padding(
          padding: const EdgeInsets.all(12),
          child: AdaptiveFilterRow(children: [
            TextField(key: const Key('filter-a'),
              decoration: const InputDecoration(labelText: 'Tỉnh')),
            TextField(key: const Key('filter-b'),
              decoration: const InputDecoration(labelText: 'Trạng thái')),
            TextField(key: const Key('filter-c'),
              decoration: const InputDecoration(labelText: 'Ngày')),
          ]),
        )),
      ));
      await tester.pump();
      final a = tester.getTopLeft(find.byKey(const Key('filter-a')));
      final b = tester.getTopLeft(find.byKey(const Key('filter-b')));
      final c = tester.getTopLeft(find.byKey(const Key('filter-c')));
      if (width < 340) {
        expect(b.dy, greaterThan(a.dy));
        expect(c.dy, greaterThan(b.dy));
      } else {
        expect(b.dy, a.dy);
        if (width < 600) {
          expect(c.dy, greaterThan(a.dy));
        } else {
          expect(c.dy, a.dy);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('P1-H mobile form handles keyboard and large text dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: SalesTheme.build(width: 360,
          brightness: dark ? Brightness.dark : Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ResponsiveFormRow(children: [
              TextField(key: const Key('province'),
                decoration: const InputDecoration(labelText: 'Tỉnh/TP')),
              TextField(key: const Key('district'),
                decoration: const InputDecoration(labelText: 'Huyện/Quận')),
            ]),
          )),
        ),
      ));
      final province = tester.getTopLeft(find.byKey(const Key('province')));
      final district = tester.getTopLeft(find.byKey(const Key('district')));
      expect(district.dy, greaterThan(province.dy));
      await tester.showKeyboard(find.byKey(const Key('province')));
      await tester.enterText(find.byKey(const Key('province')),
        'Một tỉnh có tên rất dài');
      await tester.pump();
      expect(find.text('Một tỉnh có tên rất dài'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
