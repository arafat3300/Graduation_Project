import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Screens/AddProperty.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/search.dart';
import 'package:gradproj/Screens/AdminDashboardScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      url: 'https://zodbnolhtcemthbjttab.supabase.co', 
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGJub2xodGNlbXRoYmp0dGFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ5NzE4MjMsImV4cCI6MjA1MDU0NzgyM30.bkW3OpxY1_IwU01GwybxHfrQQ9t3yFgLZVi406WvgVI', // Replace with your Supabase anon key
    );
    debugPrint("Supabase initialized successfully!");
  } catch (e) {
    debugPrint("Error initializing Supabase: $e");
  }

  final isLoggedIn = await checkIsLoggedIn();

  runApp(
    ProviderScope(
      child: MyApp(
        isLoggedIn: isLoggedIn,
      ),
    ),
  );
}

/// Check if the user is logged in
Future<bool> checkIsLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token') != null; // Check if token exists
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Property Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/property-listings',
    routes: {
      '/property-listings': (context) => const PropertyListScreen(),
      '/signup': (context) => const SignUpScreen(),
      '/login': (context) => const LoginScreen(),
      '/favourites': (context) => FavoritesScreen(),
      '/search': (context) => SearchScreen(),
      '/profile': (context) => ViewProfilePage(),
      '/addProperty' :(context)=>AddPropertyScreen(),
      '/adminDashboard': (context) => const AdminDashboardScreen()
    },
  );
  }
}
