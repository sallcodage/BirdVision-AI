import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'services/server_config.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load();
  runApp(const BirdVisionApp());
}

class BirdVisionApp extends StatelessWidget {
  const BirdVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BirdVision AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}
