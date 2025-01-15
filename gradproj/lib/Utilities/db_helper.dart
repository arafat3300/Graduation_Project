import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  // Private constructor
  DatabaseHelper._privateConstructor();

  // Getter for the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'favorites.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Create the favorites table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        propertyId INTEGER NOT NULL,
        propertyName TEXT,
        propertyType TEXT,
        UNIQUE(userId, propertyId) ON CONFLICT REPLACE
      )
    ''');
  }

  // Insert a favorite item
  Future<void> insertFavourite(Map<String, dynamic> favourite) async {
    Database db = await instance.database;
    await db.insert(
      'favorites',
      favourite,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Delete a favorite item by userId and propertyId
  Future<void> deleteFavourite(int userId, int? propertyId) async {
    Database db = await instance.database;
    await db.delete(
      'favorites',
      where: 'userId = ? AND propertyId = ?',
      whereArgs: [userId, propertyId],
    );
  }

  // Check if a property is a favorite
  Future<bool> isFavorite(int userId, int propertyId) async {
    Database db = await instance.database;
    final result = await db.query(
      'favorites',
      where: 'userId = ? AND propertyId = ?',
      whereArgs: [userId, propertyId],
    );
    return result.isNotEmpty;
  }

  // Fetch all favorites for a specific user
  Future<List<Map<String, dynamic>>> fetchFavorites(int userId) async {
    Database db = await instance.database;
    return await db.query(
      'favorites',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
  }

  // Clear all favorites (optional utility method)
  Future<void> clearAllFavorites() async {
    Database db = await instance.database;
    await db.delete('favorites');
  }
}
