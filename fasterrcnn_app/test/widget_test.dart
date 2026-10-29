import 'package:flutter_test/flutter_test.dart';

import 'package:fasterrcnn_app/api.dart';
import 'package:fasterrcnn_app/main.dart';

void main() {
  test('RF-DETR-S est le modèle par défaut et figure dans les modèles', () {
    expect(BirdVisionApi.model, 'rfdetr-s');
    expect(BirdVisionApi.models['rfdetr-s'], 'RF-DETR-S');
    expect(Settings().model, 'rfdetr-s');
  });

  testWidgets('Affiche les onglets Image et Vidéo', (tester) async {
    await tester.pumpWidget(const FasterRcnnApp());

    expect(find.text('BirdVision'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Vidéo'), findsOneWidget);
    expect(find.text('Galerie'), findsWidgets);
  });
}
