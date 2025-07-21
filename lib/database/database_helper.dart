import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createReportTables(db);
    }
    if (oldVersion < 3) {
      // Check if synced column already exists before adding it
      try {
        var result = await db.rawQuery("PRAGMA table_info(reports)");
        bool syncedExists = result.any((column) => column['name'] == 'synced');
        
        if (!syncedExists) {
          await db.execute('ALTER TABLE reports ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
        }
      } catch (e) {
        // If there's an error checking, the column might already exist
        print('Error checking/adding synced column: $e');
      }
    }
    if (oldVersion < 4) {
      // Recreate tables to ensure consistency (for development)
      await db.execute('DROP TABLE IF EXISTS detections');
      await db.execute('DROP TABLE IF EXISTS reports');
      await _createReportTables(db);
    }
  }

  Future _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        lastName TEXT,
        email TEXT UNIQUE,
        password TEXT
      )
    ''');
    
    await _createReportTables(db);
  }

  Future _createReportTables(Database db) async {
    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        sessionName TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        detectionsCount INTEGER NOT NULL,
        severityLevel TEXT NOT NULL,
        recommendations TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE detections (
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        damageType TEXT NOT NULL,
        confidence REAL NOT NULL,
        imagePath TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        boundingBox TEXT,
        severity TEXT NOT NULL,
        recommendations TEXT NOT NULL,
        FOREIGN KEY (reportId) REFERENCES reports (id)
      )
    ''');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('users');
  }

  // Report methods
  Future<int> insertReport(Map<String, dynamic> report) async {
    final db = await database;
    return await db.insert('reports', report);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedReports({String? userId}) async {
    final db = await database;
    if (userId != null) {
      return await db.query('reports', where: 'synced = 0 AND userId = ?', whereArgs: [userId]);
    }
    return await db.query('reports', where: 'synced = 0');
  }

  Future<void> markReportAsSynced(String reportId) async {
    final db = await database;
    await db.update('reports', {'synced': 1}, where: 'id = ?', whereArgs: [reportId]);
  }

  Future<List<Map<String, dynamic>>> getReports({String? userId}) async {
    final db = await database;
    if (userId != null) {
      return await db.query('reports', where: 'userId = ?', whereArgs: [userId], orderBy: 'createdAt DESC');
    }
    return await db.query('reports', orderBy: 'createdAt DESC');
  }

  Future<Map<String, dynamic>?> getReport(String id) async {
    final db = await database;
    final results = await db.query('reports', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertDetection(Map<String, dynamic> detection) async {
    final db = await database;
    return await db.insert('detections', detection);
  }

  Future<List<Map<String, dynamic>>> getDetectionsByReport(String reportId) async {
    final db = await database;
    return await db.query('detections', where: 'reportId = ?', whereArgs: [reportId]);
  }

  /// Delete a report and all its associated detections
  Future<void> deleteReport(String reportId) async {
    final db = await database;
    
    // Start a transaction to ensure both deletions succeed or fail together
    await db.transaction((txn) async {
      // Delete all detections associated with the report
      await txn.delete('detections', where: 'reportId = ?', whereArgs: [reportId]);
      
      // Delete the report itself
      await txn.delete('reports', where: 'id = ?', whereArgs: [reportId]);
    });
  }

  /// Delete multiple reports and all their associated detections
  Future<void> deleteReports(List<String> reportIds) async {
    final db = await database;
    
    if (reportIds.isEmpty) return;
    
    await db.transaction((txn) async {
      for (String reportId in reportIds) {
        // Delete all detections associated with the report
        await txn.delete('detections', where: 'reportId = ?', whereArgs: [reportId]);
        
        // Delete the report itself
        await txn.delete('reports', where: 'id = ?', whereArgs: [reportId]);
      }
    });
  }

  // Development helper method to reset database
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    await deleteDatabase(path);
    _database = null; // Force recreation on next access
  }
}


