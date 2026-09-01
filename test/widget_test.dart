import 'package:flutter_test/flutter_test.dart';

import 'package:fortress/main.dart';

void main() {
  testWidgets('App launches to the Welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FortressApp());

    expect(find.text('FORTRESS'), findsOneWidget);
    expect(find.text('CREATE NEW WALLET'), findsOneWidget);
  });
}
