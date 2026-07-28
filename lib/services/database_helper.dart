import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'security_assets.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 6) {
          await db.execute('DROP TABLE IF EXISTS assets');
          await db.execute('DROP TABLE IF EXISTS scan_logs');
          await db.execute('DROP TABLE IF EXISTS employees');
          await _onCreate(db, newVersion);
        }
      },
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS assets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id TEXT NOT NULL,
        employee_id TEXT,
        employee_name TEXT,
        model TEXT,
        serial_number TEXT
      )
    ''');

    // Sample data
    List<Map> existing = await db.query('assets', limit: 1);
    if (existing.isEmpty) {
      await db.insert('assets', {
        'asset_id': 'LAP123',
        'employee_id': 'E001',
        'employee_name': 'Mohana',
        'model': 'Dell XPS 15',
        'serial_number': 'SN123456789'
      });
    }
  }

  // Enhanced to search by both ID and Serial Number
  Future<Map<String, dynamic>?> getAssetDetails(String identifier) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'assets',
      where: 'asset_id = ? OR serial_number = ?',
      whereArgs: [identifier, identifier],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllAssets() async {
    Database db = await database;
    return await db.query('assets', orderBy: 'employee_name ASC');
  }

  Future<int> insertAsset(Map<String, dynamic> asset) async {
    Database db = await database;
    return await db.insert(
      'assets', 
      asset,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAsset(int id) async {
    Database db = await database;
    await db.delete('assets', where: 'id = ?', whereArgs: [id]);
  }
}
