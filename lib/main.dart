import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'webview_register_stub.dart'
    if (dart.library.html) 'webview_register_web.dart' as webview_register;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  webview_register.registerWebViewPlatform();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const AdevaGloveApp());
}

class AdevaGloveApp extends StatelessWidget {
  const AdevaGloveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADEVA Glove',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
          primary: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
