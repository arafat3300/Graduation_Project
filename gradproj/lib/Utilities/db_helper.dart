import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'favorites.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY,
        type TEXT,
        description TEXT
      )
    ''');
  }

  Future<int> addFavorite(Map<String, dynamic> favorite) async {
    Database db = await instance.database;
    return await db.insert('favorites', favorite);
  }

  Future<int> removeFavorite(int id) async {
    Database db = await instance.database;
    return await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    Database db = await instance.database;
    return await db.query('favorites');
  }

  Future<bool> isFavorite(int id) async {
    Database db = await instance.database;
    final result = await db.query('favorites', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty;
  }


  void addToFavorites(int id, String type, String description) async {
  final favorite = {
    'id': id,
    'type': type,
    'description': description,
  };
  await DatabaseHelper.instance.addFavorite(favorite);
  print('Added to favorites'); }

  void removeFromFavorites(int id) async {
  await DatabaseHelper.instance.removeFavorite(id);
  print('Removed from favorites'); }

  Future<bool> isFavoritee(int id) async {
  return await DatabaseHelper.instance.isFavorite(id); }

  Future<List<Map<String, dynamic>>> fetchFavorites() async {
  return await DatabaseHelper.instance.getFavorites(); }

}