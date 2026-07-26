import 'package:flutter/material.dart';

/// The PWA's "Deep Obsidian" palette, so both versions look like one product.
class Ob {
  static const bg = Color(0xFF090B10);
  static const navBg = Color(0xFF11141D);
  static const panel = Color(0xFF161A26);
  static const panel2 = Color(0xFF22283A);
  static const line = Color(0xFF313A52);
  static const amber = Color(0xFFFF9F43);
  static const amberDim = Color(0xFFD47A22);
  static const green = Color(0xFF40ECC1);
  static const greenDim = Color(0xFF106652);
  static const blue = Color(0xFF54A0FF);
  static const red = Color(0xFFFF5252);
  static const ink = Color(0xFFF0F4FC);
  static const inkDim = Color(0xFF7E8EAC);
  static const mapBg = Color(0xFF0D1117);

  // light theme
  static const lBg = Color(0xFFF4F7FC);
  static const lNavBg = Color(0xFFE4EAF3);
  static const lPanel = Color(0xFFFFFFFF);
  static const lPanel2 = Color(0xFFEDF2F9);
  static const lLine = Color(0xFFD0DBEA);
  static const lAmber = Color(0xFFD46900);
  static const lGreen = Color(0xFF0E7A63);
  static const lBlue = Color(0xFF1061CC);
  static const lRed = Color(0xFFD32F2F);
  static const lInk = Color(0xFF0E1726);
  static const lInkDim = Color(0xFF53647E);
  static const lMapBg = Color(0xFFEAEFF8);

  /// Packets stay monospace regardless of anything else.
  static const mono = TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Consolas']);
}

ThemeData obsidianTheme({required bool light}) {
  final base = light ? ThemeData.light() : ThemeData.dark();
  final ink = light ? Ob.lInk : Ob.ink;
  final dim = light ? Ob.lInkDim : Ob.inkDim;
  final amber = light ? Ob.lAmber : Ob.amber;
  final panel = light ? Ob.lPanel : Ob.panel;
  final bg = light ? Ob.lBg : Ob.bg;
  final line = light ? Ob.lLine : Ob.line;

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    colorScheme: base.colorScheme.copyWith(
      primary: amber,
      secondary: light ? Ob.lGreen : Ob.green,
      surface: panel,
      error: light ? Ob.lRed : Ob.red,
      onPrimary: const Color(0xFF03110D),
      onSurface: ink,
    ),
    dividerColor: line,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? Ob.lNavBg : Ob.navBg,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: line),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: light ? Ob.lNavBg : Ob.navBg,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, letterSpacing: .5, color: dim),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? amber : dim),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Ob.lPanel2 : Ob.panel2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: light ? Ob.lGreen : Ob.green),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: amber,
        foregroundColor: const Color(0xFF03110D),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
    ),
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    listTileTheme: ListTileThemeData(textColor: ink, iconColor: dim),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? amber : dim),
    ),
  );
}
