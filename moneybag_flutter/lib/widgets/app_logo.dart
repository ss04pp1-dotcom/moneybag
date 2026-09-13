import 'package:flutter/material.dart';

class MbAppLogo extends StatelessWidget {
  final double size;
  final bool white;

  const MbAppLogo({super.key, this.size = 96, this.white = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.account_balance_wallet, size: size * 0.5, color: Colors.green),
      ),
    );
  }
}
