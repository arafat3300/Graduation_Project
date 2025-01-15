import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradproj/Screens/AddProperty.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import 'package:gradproj/Screens/ManagePropertiesScreen.dart';
import 'package:gradproj/Screens/ManageUsersScreen.dart';
import 'package:gradproj/Screens/MyListings.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/search.dart';
import 'package:gradproj/Screens/ManageAdmins.dart';
import 'package:gradproj/Screens/AdminDashboardScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/PropertyListings.dart';
import 'screens/SignupScreen.dart';
import 'screens/LoginScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
Future<void> ensurePropertiesStatus() async {
  try {
    final supabase = Supabase.instance.client;

    
          await supabase
        .from('properties')
        .update({'status': 'unavailable'})
        .filter('user_id', 'is',null); 


  } catch (e) {
    debugPrint('Error ensuring property status: $e');
  }
}

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
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGJub2xodGNlbXRoYmp0dGFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ5NzE4MjMsImV4cCI6MjA1MDU0NzgyM30.bkW3OpxY1_IwU01GwybxHfrQQ9t3yFgLZVi406WvgVI',
    );
    debugPrint("Supabase initialized successfully!");
  } catch (e) {
    debugPrint("Error initializing Supabase: $e");
  }

  final isLoggedIn = await checkIsLoggedIn();
  ensurePropertiesStatus();

  runApp(
    ProviderScope(
      child: MyApp(
        isLoggedIn: isLoggedIn,
      ),
    ),
  );
}

Future<bool> checkIsLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token') != null;
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Property Finder',
 theme: ThemeData.light().copyWith(
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue),
),
darkTheme: ThemeData.dark().copyWith(
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blueGrey),
),
      themeMode: _themeMode,
      initialRoute: '/signup',
      routes: {
'/property-listings': (context) => PropertyListScreen(toggleTheme: toggleTheme),
        '/signup': (context) =>  SignUpScreen(toggleTheme: toggleTheme),
        '/login': (context) =>  LoginScreen(toggleTheme: toggleTheme),
         '/favourites': (context) => FavoritesScreen(toggleTheme: toggleTheme),
        '/search': (context) =>  SearchScreen(toggleTheme: toggleTheme),
        '/profile': (context) => ViewProfilePage(),
        '/addProperty': (context) => AddPropertyScreen(),
        '/adminDashboard': (context) => const AdminDashboardScreen(),
        '/manageAdmins': (context) => const ManageAdminsScreen(),
        '/manageUsers': (context) => const ManageUsersScreen(),
        '/manageProps': (context) => const ManagePropertiesScreen(),
       
        

        
      },
    );
  }
}
