import 'package:flutter/material.dart';

/// 区分グリッド用カラーパレット（マスターに色が無いため index で循環）
const List<Color> kZaiconCategoryColors = [
  Color(0xFFDC2626),
  Color(0xFF2563EB),
  Color(0xFF059669),
  Color(0xFF9333EA),
  Color(0xFF111827),
  Color(0xFF9A3412),
];

Color zaiconCategoryColorAt(int index) {
  if (kZaiconCategoryColors.isEmpty) return const Color(0xFF2563EB);
  return kZaiconCategoryColors[index % kZaiconCategoryColors.length];
}

const String kZaiconAppName = 'RentalSync Pro';
