import 'package:flutter_test/flutter_test.dart';
import 'package:selection_lab/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SelectionLabApp());
  });
}
