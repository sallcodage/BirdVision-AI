import 'package:flutter/material.dart';

class BrandColors {
  static const night = Color(0xFF061827);
  static const blue = Color(0xFF1268E8);
  static const cyan = Color(0xFF22D3EE);
  static const background = Color(0xFFF5FAFF);
  static const softText = Color(0xFF9DBDCE);

  static const logoAsset = 'assets/images/birdvision-logo.png';

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF04131F), Color(0xFF07263E), Color(0xFF074C70)],
  );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: BrandColors.cyan.withValues(alpha: 0.22),
            blurRadius: size * 0.4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Image.asset(BrandColors.logoAsset, fit: BoxFit.cover),
    );
  }
}
