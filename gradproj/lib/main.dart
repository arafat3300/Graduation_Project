import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/search.dart';
import 'screens/PropertyListings.dart';
import 'screens/SignupScreen.dart';
import 'screens/LoginScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase initialized successfully!");
  } catch (e) {
    debugPrint("Error initializing Firebase: $e");
  }

  try {
    await Supabase.initialize(
      url: 'https://zodbnolhtcemthbjttab.supabase.co', // Replace with your Supabase project URL
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGJub2xodGNlbXRoYmp0dGFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ5NzE4MjMsImV4cCI6MjA1MDU0NzgyM30.bkW3OpxY1_IwU01GwybxHfrQQ9t3yFgLZVi406WvgVI', // Replace with your Supabase anon key
    );
    debugPrint("Supabase initialized successfully!");
  } catch (e) {
    debugPrint("Error initializing Supabase: $e");
  }
 runApp(
    ProviderScope(
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Property Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PropertyListScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/favourites': (context) => FavoritesScreen(),
                '/search': (context) => SearchScreen(),
                '/profile': (context) => ViewProfilePage(),



      },
    );
  }
}
