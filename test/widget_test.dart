import 'package:flutter_test/flutter_test.dart';
import 'package:lexflow_app/main.dart'; // 'lexflow_app' kısmının pubspec.yaml'daki name ile aynı olduğundan emin olun

void main() {
  testWidgets('Uygulama yükleme testi', (WidgetTester tester) async {
    // Uygulamayı başlatır
    await tester.pumpWidget(const LexFlowApp());

    // Ekranda 'LexFlow' başlığının olduğunu doğrular
    expect(find.text('LexFlow'), findsOneWidget);
  });
}