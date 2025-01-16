import 'package:flutter/material.dart';
import 'package:gradproj/Screens/CustomBottomNavBar.dart';
import 'package:gradproj/Screens/FavouritesScreen.dart';
import 'package:gradproj/Screens/Profile.dart';
import 'package:gradproj/Screens/PropertyListings.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';

class SearchScreen extends StatefulWidget {
    final VoidCallback toggleTheme;

  const SearchScreen({super.key, required this.toggleTheme});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  int _currentIndex = 3; // Default index for Search Screen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Prevent resizing when the keyboard is shown
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          buildMap(), // Your map widget here
          buildFloatingSearchBar(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Add logic here to navigate to other pages if needed
          if (_currentIndex == 0) {
Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyListScreen(toggleTheme: widget.toggleTheme),
              ),
            );          } else if (_currentIndex == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>  SearchScreen(toggleTheme: widget.toggleTheme),
              ),
            );
          } else if (_currentIndex == 3) {
Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewProfilePage(),
              ),
);
          } else if (_currentIndex == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>  FavoritesScreen(toggleTheme: widget.toggleTheme),
              ),
            );
          }
        },
      ),
    );
  }

  /// Floating Search Bar
  Widget buildFloatingSearchBar() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return FloatingSearchBar(
      hint: 'Search...',
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      physics: const BouncingScrollPhysics(),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
      width: isPortrait ? 600 : 500,
      debounceDelay: const Duration(milliseconds: 500),
      onQueryChanged: (query) {
        // Perform search operations here
        print('Search query: $query');
      },
      transition: CircularFloatingSearchBarTransition(),
      actions: [
        FloatingSearchBarAction(
          showIfOpened: false,
          child: CircularButton(
            icon: const Icon(Icons.place),
            onPressed: () {
              print('Place button pressed');
            },
          ),
        ),
        FloatingSearchBarAction.searchToClear(
          showIfClosed: false,
        ),
      ],
      builder: (context, transition) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.white,
            elevation: 4.0,
            child: ListView(
              shrinkWrap: true,
              children: List.generate(
                5,
                (index) => ListTile(
                  title: Text('Search Result $index'),
                  onTap: () {
                    // Handle result click
                    print('Selected search result $index');
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Map Placeholder Widget
  Widget buildMap() {
    return Container(
      color: Colors.blue[100], // Replace with your map widget
      child: const Center(
        child: Text(
          'Map Placeholder',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
