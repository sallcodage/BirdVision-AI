import 'package:flutter_test/flutter_test.dart';
import 'package:birdvision_rfdetr/main.dart';

void main() {
  testWidgets('BirdVision RF-DETR application launches',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BirdVisionRfDetrApp());

    expect(find.byType(BirdVisionRfDetrApp), findsOneWidget);
  });
}