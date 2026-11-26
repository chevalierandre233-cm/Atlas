import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'theme/atlas_theme.dart';

void main() => runApp(const AtlasApp());

class AtlasApp extends StatefulWidget {
  const AtlasApp({super.key});
  @override
  State<AtlasApp> createState() => _AtlasAppState();
}

class _AtlasAppState extends State<AtlasApp> {
  ThemeMode _mode = ThemeMode.dark; // sombre par défaut

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Atlas',
      theme: AtlasTheme.build(Brightness.light),
      darkTheme: AtlasTheme.build(Brightness.dark),
      themeMode: _mode,
      home: ChatScreen(
        isDark: _mode == ThemeMode.dark,
        onToggleTheme: () => setState(() =>
            _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
      ),
    );
  }
}
