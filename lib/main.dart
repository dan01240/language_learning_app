import 'package:flutter/material.dart';
import 'package:language_learning_app/app/router.dart';

void main() async {
  // Flutter binding initialization is required before any platform channels are used
  WidgetsFlutterBinding.ensureInitialized();

  // Run the app with the router
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use the router from AppRouter
    return MaterialApp.router(
      title: 'Language Learning App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
