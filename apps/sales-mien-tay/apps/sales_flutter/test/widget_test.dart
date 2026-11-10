import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/models.dart';

void main() {
  test('Sales module inventory contains seven unique kinds', () {
    expect(moduleKinds, hasLength(7));
    expect(moduleKinds.toSet(), hasLength(7));
    for (final kind in moduleKinds) {
      expect(moduleLabels.containsKey(kind), isTrue);
    }
  });
}
