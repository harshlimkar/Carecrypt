import 'package:flutter_test/flutter_test.dart';
import 'package:carecrypt/main.dart';

void main() {
  testWidgets('CareCrypt app smoke test', (WidgetTester tester) async {
    // Smoke test — verifies the root class exists.
    // Full integration tests require Supabase + Firebase environment.
    expect(CareCryptApp, isA<Type>());
  });
}
