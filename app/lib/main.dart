import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import './screens/home_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import './l10n/app_localizations.dart';

void main() {
  // Add global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    developer.log('Application error', error: details.toString());
  };
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroTier for Magisk',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.lightBlue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.lightBlue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
