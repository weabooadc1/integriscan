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
      version: 7, // Incremented for damage type schema migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await _createTables(db);
    await _createEngineerVerificationTable(db);
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
    if (oldVersion < 5) {
      // Add engineer verification fields
      try {
        var result = await db.rawQuery("PRAGMA table_info(reports)");
        bool flaggedExists = result.any((column) => column['name'] == 'flaggedForVerification');
        
        if (!flaggedExists) {
          await db.execute('ALTER TABLE reports ADD COLUMN flaggedForVerification INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE reports ADD COLUMN flaggedAt TEXT');
          await db.execute('ALTER TABLE reports ADD COLUMN verificationStatus TEXT NOT NULL DEFAULT "none"');
          await db.execute('ALTER TABLE reports ADD COLUMN engineerComments TEXT');
          await db.execute('ALTER TABLE reports ADD COLUMN reviewedAt TEXT');
          print('Added engineer verification columns to reports table');
        }
        
        // Create engineer verification table if it doesn't exist
        try {
          await _createEngineerVerificationTable(db);
          print('Created engineer_verification table');
        } catch (e) {
          // Table might already exist
          print('Engineer verification table might already exist: $e');
        }
        
      } catch (e) {
        print('Error adding engineer verification columns: $e');
      }
    }
    if (oldVersion < 6) {
      // Fix engineer verification table schema
      try {
        // Drop and recreate the engineer_verification table with correct schema
        await db.execute('DROP TABLE IF EXISTS engineer_verification');
        await _createEngineerVerificationTable(db);
        print('Recreated engineer_verification table with correct schema');
      } catch (e) {
        print('Error fixing engineer verification table schema: $e');
      }
    }
    if (oldVersion < 7) {
      // Migrate to damage type categorization system
      try {
        // Add new columns for damage type counts to reports table
        var result = await db.rawQuery("PRAGMA table_info(reports)");
        bool cracksCountExists = result.any((column) => column['name'] == 'cracksCount');
        
        if (!cracksCountExists) {
          await db.execute('ALTER TABLE reports ADD COLUMN cracksCount INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE reports ADD COLUMN corrosionCount INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE reports ADD COLUMN deformationCount INTEGER NOT NULL DEFAULT 0');
          print('Added damage type count columns to reports table');
          
          // Migrate existing reports by calculating damage type counts from their detections
          await _migrateDamageTypeCounts(db);
        }
        
        print('Successfully migrated to damage type categorization system');
      } catch (e) {
        print('Error migrating to damage type system: $e');
      }
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
        cracksCount INTEGER NOT NULL DEFAULT 0,
        corrosionCount INTEGER NOT NULL DEFAULT 0,
        deformationCount INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        flaggedForVerification INTEGER NOT NULL DEFAULT 0,
        flaggedAt TEXT,
        verificationStatus TEXT NOT NULL DEFAULT 'none',
        engineerComments TEXT,
        reviewedAt TEXT
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

  Future _createEngineerVerificationTable(Database db) async {
    await db.execute('''
      CREATE TABLE engineer_verification (
        id TEXT PRIMARY KEY,
        originalReportId TEXT NOT NULL,
        userId TEXT NOT NULL,
        flaggedAt TEXT NOT NULL,
        reportSnapshot TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'review',
        engineerComments TEXT,
        engineerId TEXT,
        reviewedAt TEXT,
        FOREIGN KEY (originalReportId) REFERENCES reports (id)
      )
    ''');
  }

  /// Migrate existing reports to calculate damage type counts from their detections
  Future _migrateDamageTypeCounts(Database db) async {
    try {
      print('Starting damage type counts migration...');
      
      // Get all reports
      final reports = await db.query('reports');
      
      for (final report in reports) {
        final reportId = report['id'] as String;
        
        // Get all detections for this report
        final detections = await db.query('detections', where: 'reportId = ?', whereArgs: [reportId]);
        
        // Count damage types using the same logic as in report_service.dart
        int cracksCount = 0;
        int corrosionCount = 0;
        int deformationCount = 0;
        
        for (final detection in detections) {
          final damageType = (detection['damageType'] as String).toLowerCase();
          
          if (damageType.contains('crack')) {
            cracksCount++;
          } else if (damageType.contains('corrosion') || 
                     damageType.contains('rust') || 
                     damageType.contains('scaling')) {
            corrosionCount++;
          } else if (damageType.contains('deformation') || 
                     damageType.contains('deform')) {
            deformationCount++;
          }
        }
        
        // Update the report with calculated counts
        await db.update(
          'reports',
          {
            'cracksCount': cracksCount,
            'corrosionCount': corrosionCount,
            'deformationCount': deformationCount,
          },
          where: 'id = ?',
          whereArgs: [reportId],
        );
        
        print('Migrated report $reportId: $cracksCount cracks, $corrosionCount corrosion, $deformationCount deformation');
      }
      
      print('Completed damage type counts migration for ${reports.length} reports');
    } catch (e) {
      print('Error during damage type counts migration: $e');
    }
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

  // Engineer Verification methods
  Future<int> insertEngineerVerification(Map<String, dynamic> verification) async {
    final db = await database;
    return await db.insert('engineer_verification', verification);
  }

  Future<List<Map<String, dynamic>>> getAllEngineerVerifications() async {
    final db = await database;
    return await db.query('engineer_verification', orderBy: 'flaggedAt DESC');
  }

  Future<List<Map<String, dynamic>>> getEngineerVerificationsByStatus(String status) async {
    final db = await database;
    return await db.query(
      'engineer_verification', 
      where: 'status = ?', 
      whereArgs: [status],
      orderBy: 'flaggedAt DESC'
    );
  }

  Future<Map<String, dynamic>?> getEngineerVerificationById(String id) async {
    final db = await database;
    final results = await db.query('engineer_verification', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getEngineerVerificationByReportId(String reportId) async {
    final db = await database;
    final results = await db.query('engineer_verification', where: 'originalReportId = ?', whereArgs: [reportId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateEngineerVerification(String id, Map<String, dynamic> verification) async {
    final db = await database;
    return await db.update('engineer_verification', verification, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteEngineerVerification(String id) async {
    final db = await database;
    await db.delete('engineer_verification', where: 'id = ?', whereArgs: [id]);
  }

  // Update report verification status
  Future<int> updateReportVerificationStatus(String reportId, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update('reports', updates, where: 'id = ?', whereArgs: [reportId]);
  }

  // Get reports by verification status
  Future<List<Map<String, dynamic>>> getReportsByVerificationStatus(String status) async {
    final db = await database;
    return await db.query(
      'reports',
      where: 'verificationStatus = ?',
      whereArgs: [status],
      orderBy: 'flaggedAt DESC'
    );
  }

  // Migration method to update existing verification status values to new terminology
  Future<void> migrateVerificationStatusTerminology() async {
    final db = await database;
    try {
      // Update reports table: pending -> review, approved -> clear, rejected -> issues
      await db.rawUpdate(
        'UPDATE reports SET verificationStatus = ? WHERE verificationStatus = ?',
        ['review', 'pending']
      );
      await db.rawUpdate(
        'UPDATE reports SET verificationStatus = ? WHERE verificationStatus = ?',
        ['clear', 'approved']
      );
      await db.rawUpdate(
        'UPDATE reports SET verificationStatus = ? WHERE verificationStatus = ?',
        ['issues', 'rejected']
      );
      
      // Update engineer_verification table: pending -> review, approved -> clear, rejected -> issues
      await db.rawUpdate(
        'UPDATE engineer_verification SET status = ? WHERE status = ?',
        ['review', 'pending']
      );
      await db.rawUpdate(
        'UPDATE engineer_verification SET status = ? WHERE status = ?',
        ['clear', 'approved']
      );
      await db.rawUpdate(
        'UPDATE engineer_verification SET status = ? WHERE status = ?',
        ['issues', 'rejected']
      );
      
      print('Successfully migrated verification status terminology');
    } catch (e) {
      print('Error during verification status terminology migration: $e');
    }
  }
}


