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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // 1. Employees Table
    await db.execute('''
      CREATE TABLE employees(
        emp_id TEXT PRIMARY KEY,
        emp_name TEXT NOT NULL,
        department TEXT,
        status TEXT DEFAULT 'active'
      )
    ''');

    // 2. Assets Table
    await db.execute('''
      CREATE TABLE assets(
        asset_id TEXT PRIMARY KEY,
        asset_type TEXT NOT NULL,
        is_company INTEGER DEFAULT 1,
        emp_id TEXT,
        status TEXT DEFAULT 'active',
        last_updated TEXT,
        FOREIGN KEY (emp_id) REFERENCES employees (emp_id)
      )
    ''');

    // 3. Scan Logs Table
    await db.execute('''
      CREATE TABLE scan_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id TEXT,
        scan_time TEXT,
        result TEXT,
        scanned_by TEXT
      )
    ''');

    // Pre-populate some sample data for testing
    await db.insert('employees', {
      'emp_id': 'E001',
      'emp_name': 'Mohana',
      'department': 'Security',
      'status': 'active'
    });

    await db.insert('assets', {
      'asset_id': 'LAP123',
      'asset_type': 'Laptop',
      'is_company': 1,
      'emp_id': 'E001',
      'status': 'active',
      'last_updated': DateTime.now().toIso8601String()
    });
  }

  Future<Map<String, dynamic>?> getAssetDetails(String qrCode) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT a.*, e.emp_name, e.department 
      FROM assets a
      LEFT JOIN employees e ON a.emp_id = e.emp_id
      WHERE a.asset_id = ?
    ''', [qrCode]);

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<void> logScan(String assetId, String result, String scannedBy) async {
    Database db = await database;
    await db.insert('scan_logs', {
      'asset_id': assetId,
      'scan_time': DateTime.now().toIso8601String(),
      'result': result,
      'scanned_by': scannedBy
    });
  }

  Future<List<Map<String, dynamic>>> getScanLogs() async {
    Database db = await database;
    // Query logs joined with asset and employee info for better history view
    return await db.rawQuery('''
      SELECT sl.*, a.asset_type, e.emp_name 
      FROM scan_logs sl
      LEFT JOIN assets a ON sl.asset_id = a.asset_id
      LEFT JOIN employees e ON a.emp_id = e.emp_id
      ORDER BY sl.scan_time DESC
    ''');
  }

  Future<void> clearLogs() async {
    Database db = await database;
    await db.delete('scan_logs');
  }
}
