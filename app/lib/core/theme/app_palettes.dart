import 'package:flutter/material.dart';

/// A single named color palette entry.
class AppPalette {
  const AppPalette({
    required this.nameKey,
    required this.seed,
  });

  /// Translation key for the palette name (e.g. `settings.palette_ocean`).
  final String nameKey;

  /// Seed color passed to [ColorScheme.fromSeed].
  final Color seed;
}

/// All available color palettes in display order.
const List<AppPalette> kAppPalettes = <AppPalette>[
  AppPalette(nameKey: 'settings.palette_ocean',  seed: Color(0xFF4A8DFF)),
  AppPalette(nameKey: 'settings.palette_forest', seed: Color(0xFF2E7D32)),
  AppPalette(nameKey: 'settings.palette_purple', seed: Color(0xFF7B1FA2)),
  AppPalette(nameKey: 'settings.palette_sunset', seed: Color(0xFFE64A19)),
  AppPalette(nameKey: 'settings.palette_rose',   seed: Color(0xFFE91E63)),
  AppPalette(nameKey: 'settings.palette_teal',   seed: Color(0xFF00897B)),
  AppPalette(nameKey: 'settings.palette_golden', seed: Color(0xFFF57F17)),
  AppPalette(nameKey: 'settings.palette_indigo', seed: Color(0xFF3949AB)),
];
