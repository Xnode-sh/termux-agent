import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final String risk;
  const RiskBadge({super.key, required this.risk});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (risk) {
      'safe'   => (const Color(0xFF3FB950), 'SAFE'),
      'write'  => (const Color(0xFFD29922), 'WRITE'),
      'danger' => (const Color(0xFFF85149), 'DANGER'),
      _        => (const Color(0xFF8B949E), risk.toUpperCase()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
    );
  }
}
