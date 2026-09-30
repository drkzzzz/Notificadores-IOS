import 'package:flutter_test/flutter_test.dart';

import 'package:notificadores_satt/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SatApp());
  });
}
