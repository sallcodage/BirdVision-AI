import 'package:flutter_test/flutter_test.dart';

import 'package:dfine_app/main.dart';

void main() {
  testWidgets('Affiche les onglets Image et Vidéo', (tester) async {
    await tester.pumpWidget(const DfineApp());

    expect(find.text('BirdVision'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Vidéo'), findsOneWidget);
    expect(find.text('Galerie'), findsWidgets);
  });
}
