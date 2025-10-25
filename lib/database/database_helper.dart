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
    // Ensure 'deleted' column exists for older databases that may not have been migrated
    try {
      await _ensureDeletedColumnExists(_database!);
    } catch (e) {
      print('Warning: failed to ensure deleted column exists: $e');
    }
    return _database!;
  }

  /// Ensure the 'deleted' column exists in reports table; if missing, add it.
  Future<void> _ensureDeletedColumnExists(Database db) async {
    try {
      final result = await db.rawQuery("PRAGMA table_info(reports)");
      final hasDeleted = result.any((column) => column['name'] == 'deleted');
      if (!hasDeleted) {
        print('Reports table missing "deleted" column - adding it now');
        await db.execute('ALTER TABLE reports ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
        print('Added "deleted" column to reports table');
      }
    } catch (e) {
      // If reports table doesn't exist yet (first-run), ignore; onCreate will create with the column
      print('Error while checking/adding deleted column (may be safe on first run): $e');
    }
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    return await openDatabase(
      path,
      version: 11, // Incremented for userFlaggingComments field
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await _createTables(db);
    await _createEngineerVerificationTable(db);
    await _createPendingFlagOperationsTable(db);
    await _createReportRecommendationsTable(db);
    await _createDetectionCountTriggers(db);
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
    if (oldVersion < 8) {
      // Add offline flagging support
      try {
        var result = await db.rawQuery("PRAGMA table_info(reports)");
        bool pendingFlagSyncExists = result.any((column) => column['name'] == 'pendingFlagSync');
        
        if (!pendingFlagSyncExists) {
          await db.execute('ALTER TABLE reports ADD COLUMN pendingFlagSync INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE reports ADD COLUMN offlineFlaggedAt TEXT');
          // Add deleted flag to mark reports that were removed locally but may be in-flight for upload
          await db.execute('ALTER TABLE reports ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
          print('Added offline flagging columns to reports table');
        }
        
        // Create pending_flag_operations table for queuing flag operations
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pending_flag_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reportId TEXT NOT NULL,
            operation TEXT NOT NULL,
            operationData TEXT,
            timestamp TEXT NOT NULL,
            userId TEXT NOT NULL,
            retryCount INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (reportId) REFERENCES reports (id)
          )
        ''');
        
        print('Successfully added offline flagging support');
      } catch (e) {
        print('Error adding offline flagging support: $e');
      }
    }
    if (oldVersion < 9) {
      // SECURITY FIX: Remove password column from users table
      try {
        print('🔒 SECURITY MIGRATION: Removing plain text password storage...');
        
        // Check if password column exists
        var result = await db.rawQuery("PRAGMA table_info(users)");
        bool passwordExists = result.any((column) => column['name'] == 'password');
        
        if (passwordExists) {
          // SQLite doesn't support DROP COLUMN directly, so we need to recreate the table
          
          // 1. Rename old table
          await db.execute('ALTER TABLE users RENAME TO users_old');
          
          // 2. Create new table without password
          await db.execute('''
            CREATE TABLE users(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              firstName TEXT NOT NULL,
              lastName TEXT NOT NULL,
              email TEXT UNIQUE NOT NULL,
              firebaseUid TEXT UNIQUE,
              createdAt TEXT,
              updatedAt TEXT,
              CONSTRAINT chk_email CHECK (email LIKE '%@%.%')
            )
          ''');
          
          // 3. Copy data from old table (excluding password)
          await db.execute('''
            INSERT INTO users (id, firstName, lastName, email, firebaseUid, createdAt, updatedAt)
            SELECT id, firstName, lastName, email, 
                   NULL as firebaseUid, 
                   datetime('now') as createdAt,
                   datetime('now') as updatedAt
            FROM users_old
          ''');
          
          // 4. Drop old table
          await db.execute('DROP TABLE users_old');
          
          print('✅ SECURITY FIX COMPLETE: Password column removed from users table');
          print('⚠️  Note: Users will need to use Firebase Authentication for login');
        } else {
          print('✅ Password column does not exist - database already secure');
        }
      } catch (e) {
        print('❌ Error during password removal migration: $e');
        print('⚠️  Manual intervention may be required');
      }
    }
    if (oldVersion < 10) {
      // NORMALIZATION: Create report_recommendations table and triggers
      try {
        print('🔧 NORMALIZATION MIGRATION: Creating report_recommendations table...');
        
        // 1. Create report_recommendations table
        await _createReportRecommendationsTable(db);
        print('✅ Created report_recommendations table');
        
        // 2. Migrate existing recommendations from reports table
        final reports = await db.query('reports');
        print('📊 Migrating recommendations for ${reports.length} reports...');
        
        int migratedCount = 0;
        for (final report in reports) {
          final reportId = report['id'] as String;
          final recommendations = (report['recommendations'] as String).split('|').where((r) => r.trim().isNotEmpty).toList();
          
          for (int i = 0; i < recommendations.length; i++) {
            await db.insert('report_recommendations', {
              'reportId': reportId,
              'recommendation': recommendations[i].trim(),
              'displayOrder': i,
            });
            migratedCount++;
          }
        }
        print('✅ Migrated $migratedCount recommendations');
        
        // 3. Create triggers to auto-update detection counts
        await _createDetectionCountTriggers(db);
        print('✅ Created triggers for automatic count updates');
        
        // 4. Add CHECK constraints for data integrity
        // Note: SQLite doesn't support adding constraints to existing tables easily
        // We'll rely on triggers and application logic
        
        print('✅ NORMALIZATION COMPLETE: Database is now normalized');
      } catch (e) {
        print('❌ Error during normalization migration: $e');
        print('⚠️  Manual intervention may be required');
      }
    }
    if (oldVersion < 11) {
      // Add userFlaggingComments column to separate user comments from engineer comments
      try {
        print('🔧 MIGRATION v11: Adding userFlaggingComments column...');
        
        var result = await db.rawQuery("PRAGMA table_info(reports)");
        bool columnExists = result.any((column) => column['name'] == 'userFlaggingComments');
        
        if (!columnExists) {
          await db.execute('ALTER TABLE reports ADD COLUMN userFlaggingComments TEXT');
          print('✅ Added userFlaggingComments column to reports table');
          
          // Migrate existing data: If engineerComments exists and report is flagged but not reviewed,
          // it's likely a user's flagging comment that was incorrectly stored
          await db.execute('''
            UPDATE reports 
            SET userFlaggingComments = engineerComments,
                engineerComments = NULL
            WHERE flaggedForVerification = 1 
              AND verificationStatus = 'review'
              AND reviewedAt IS NULL
              AND engineerComments IS NOT NULL
          ''');
          print('✅ Migrated existing flagging comments to userFlaggingComments field');
        } else {
          print('✅ userFlaggingComments column already exists');
        }
      } catch (e) {
        print('❌ Error during userFlaggingComments migration: $e');
      }
    }
  }

  Future _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        firebaseUid TEXT UNIQUE NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        CONSTRAINT chk_email CHECK (email LIKE '%@%.%')
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
        userFlaggingComments TEXT,
        engineerComments TEXT,
        reviewedAt TEXT,
        pendingFlagSync INTEGER NOT NULL DEFAULT 0,
        offlineFlaggedAt TEXT
        ,deleted INTEGER NOT NULL DEFAULT 0
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

  Future _createPendingFlagOperationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE pending_flag_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reportId TEXT NOT NULL,
        operation TEXT NOT NULL,
        operationData TEXT,
        timestamp TEXT NOT NULL,
        userId TEXT NOT NULL,
        retryCount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (reportId) REFERENCES reports (id)
      )
    ''');
  }

  /// Create normalized recommendations table (3NF)
  Future _createReportRecommendationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE report_recommendations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reportId TEXT NOT NULL,
        recommendation TEXT NOT NULL,
        displayOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (reportId) REFERENCES reports (id) ON DELETE CASCADE
      )
    ''');
    
    // Create index for faster lookups
    await db.execute('''
      CREATE INDEX idx_report_recommendations_reportId 
      ON report_recommendations(reportId)
    ''');
  }

  /// Create triggers to automatically update detection counts
  Future _createDetectionCountTriggers(Database db) async {
    // Trigger: After inserting a detection, update parent report counts
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_counts_after_detection_insert
      AFTER INSERT ON detections
      BEGIN
        UPDATE reports
        SET 
          detectionsCount = (SELECT COUNT(*) FROM detections WHERE reportId = NEW.reportId),
          cracksCount = (SELECT COUNT(*) FROM detections WHERE reportId = NEW.reportId AND lower(damageType) LIKE '%crack%'),
          corrosionCount = (SELECT COUNT(*) FROM detections WHERE reportId = NEW.reportId AND (lower(damageType) LIKE '%corrosion%' OR lower(damageType) LIKE '%rust%' OR lower(damageType) LIKE '%scaling%')),
          deformationCount = (SELECT COUNT(*) FROM detections WHERE reportId = NEW.reportId AND (lower(damageType) LIKE '%deformation%' OR lower(damageType) LIKE '%deform%'))
        WHERE id = NEW.reportId;
      END;
    ''');
    
    // Trigger: After deleting a detection, update parent report counts
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_counts_after_detection_delete
      AFTER DELETE ON detections
      BEGIN
        UPDATE reports
        SET 
          detectionsCount = (SELECT COUNT(*) FROM detections WHERE reportId = OLD.reportId),
          cracksCount = (SELECT COUNT(*) FROM detections WHERE reportId = OLD.reportId AND lower(damageType) LIKE '%crack%'),
          corrosionCount = (SELECT COUNT(*) FROM detections WHERE reportId = OLD.reportId AND (lower(damageType) LIKE '%corrosion%' OR lower(damageType) LIKE '%rust%' OR lower(damageType) LIKE '%scaling%')),
          deformationCount = (SELECT COUNT(*) FROM detections WHERE reportId = OLD.reportId AND (lower(damageType) LIKE '%deformation%' OR lower(damageType) LIKE '%deform%'))
        WHERE id = OLD.reportId;
      END;
    ''');
    
    // Trigger: After updating a detection's damageType, update parent report counts
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_counts_after_detection_update
      AFTER UPDATE OF damageType ON detections
      BEGIN
        UPDATE reports
        SET 
          cracksCount = (SELECT COUNT(*) FROM detections WHERE reportId = NEW.reportId AND lower(damageType) LIKE '%crack%'),
          corrosionCount = (SELECT COUNT(*) FROM detections WHERE reportId = NEW.reportId AND (lower(damageType) LIKE '%corrosion%' OR lower(damageType) LIKE '%rust%' OR lower(damageType) LIKE '%scaling%')),
          deformationCount = (SELECT COUNT(*) FROM detections WHERE reportId = NEW.reportId AND (lower(damageType) LIKE '%deformation%' OR lower(damageType) LIKE '%deform%'))
        WHERE id = NEW.reportId;
      END;
    ''');
    
    print('✅ Created detection count triggers');
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
    // Ensure required fields are present
    if (!user.containsKey('firebaseUid')) {
      throw ArgumentError('firebaseUid is required');
    }
    if (!user.containsKey('createdAt')) {
      user['createdAt'] = DateTime.now().toIso8601String();
    }
    if (!user.containsKey('updatedAt')) {
      user['updatedAt'] = DateTime.now().toIso8601String();
    }
    // Remove password if accidentally passed (security)
    user.remove('password');
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
    
    // Extract recommendations before inserting report
    List<String> recommendations = [];
    if (report.containsKey('recommendations')) {
      final recsValue = report['recommendations'];
      if (recsValue is String) {
        recommendations = recsValue.split('|').where((r) => r.trim().isNotEmpty).toList();
      } else if (recsValue is List) {
        recommendations = recsValue.map((r) => r.toString()).where((r) => r.trim().isNotEmpty).toList();
      }
    }
    
    // Keep pipe-delimited format in reports table for backward compatibility
    final reportToInsert = Map<String, dynamic>.from(report);
    if (recommendations.isNotEmpty) {
      reportToInsert['recommendations'] = recommendations.join('|');
    }
    
    // Insert the report
    final result = await db.insert('reports', reportToInsert);
    
    // Insert recommendations into normalized table
    if (recommendations.isNotEmpty) {
      final reportId = report['id'] as String;
      await _insertReportRecommendations(reportId, recommendations);
    }
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedReports({String? userId}) async {
    final db = await database;
    if (userId != null) {
      // Exclude reports that have been marked deleted locally
      return await db.query('reports', where: 'synced = 0 AND deleted = 0 AND userId = ?', whereArgs: [userId]);
    }
    return await db.query('reports', where: 'synced = 0 AND deleted = 0');
  }

  Future<void> markReportAsSynced(String reportId) async {
    final db = await database;
    await db.update('reports', {'synced': 1}, where: 'id = ?', whereArgs: [reportId]);
  }

  /// Mark a report as deleted locally (soft delete) so that any in-flight syncs will skip it
  Future<int> markReportDeleted(String reportId) async {
    final db = await database;
    return await db.update('reports', {'deleted': 1}, where: 'id = ?', whereArgs: [reportId]);
  }

  /// Check whether a report is marked deleted
  Future<bool> isReportDeleted(String reportId) async {
    final db = await database;
    final results = await db.query('reports', where: 'id = ?', whereArgs: [reportId], limit: 1);
    if (results.isEmpty) return true; // If it's gone, treat as deleted
    return (results.first['deleted'] ?? 0) == 1;
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
      // Delete recommendations first (even though CASCADE should handle it)
      await txn.delete('report_recommendations', where: 'reportId = ?', whereArgs: [reportId]);
      
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
        // Delete recommendations
        await txn.delete('report_recommendations', where: 'reportId = ?', whereArgs: [reportId]);
        
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

  // Offline flagging operations methods
  Future<int> addPendingFlagOperation(String reportId, String operation, String operationData, String userId) async {
    final db = await database;
    return await db.insert('pending_flag_operations', {
      'reportId': reportId,
      'operation': operation,
      'operationData': operationData,
      'timestamp': DateTime.now().toIso8601String(),
      'userId': userId,
      'retryCount': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingFlagOperations() async {
    final db = await database;
    return await db.query('pending_flag_operations', orderBy: 'timestamp ASC');
  }

  Future<void> removePendingFlagOperation(int operationId) async {
    final db = await database;
    await db.delete('pending_flag_operations', where: 'id = ?', whereArgs: [operationId]);
  }

  Future<void> incrementRetryCount(int operationId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_flag_operations SET retryCount = retryCount + 1 WHERE id = ?',
      [operationId]
    );
  }

  Future<int> updateReportOfflineFlagStatus(String reportId, {bool? pendingFlagSync, String? offlineFlaggedAt}) async {
    final db = await database;
    Map<String, dynamic> values = {};
    
    if (pendingFlagSync != null) {
      values['pendingFlagSync'] = pendingFlagSync ? 1 : 0;
    }
    if (offlineFlaggedAt != null) {
      values['offlineFlaggedAt'] = offlineFlaggedAt;
    }
    
    return await db.update(
      'reports',
      values,
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  Future<List<Map<String, dynamic>>> getReportsWithPendingFlagSync() async {
    final db = await database;
    return await db.query(
      'reports',
      where: 'pendingFlagSync = ?',
      whereArgs: [1],
      orderBy: 'offlineFlaggedAt DESC',
    );
  }

  /// Get the last sync time for a user
  Future<DateTime?> getLastSyncTime(String userId) async {
    final db = await database;
    try {
      final result = await db.query(
        'user_sync_times',
        where: 'userId = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final timestamp = result.first['lastSyncTime'] as String;
        return DateTime.parse(timestamp);
      }
      return null;
    } catch (e) {
      // Table might not exist yet, create it
      await _createUserSyncTimesTable(db);
      return null;
    }
  }

  /// Update the last sync time for a user
  Future<void> updateLastSyncTime(String userId) async {
    final db = await database;
    try {
      await db.insert(
        'user_sync_times',
        {
          'userId': userId,
          'lastSyncTime': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Table might not exist yet, create it
      await _createUserSyncTimesTable(db);
      await db.insert(
        'user_sync_times',
        {
          'userId': userId,
          'lastSyncTime': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Create user sync times table
  Future<void> _createUserSyncTimesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_sync_times (
        userId TEXT PRIMARY KEY,
        lastSyncTime TEXT NOT NULL
      )
    ''');
  }

  // ============================================================================
  // NORMALIZED RECOMMENDATIONS METHODS
  // ============================================================================

  /// Insert recommendations for a report into the normalized table
  Future<void> _insertReportRecommendations(String reportId, List<String> recommendations) async {
    final db = await database;
    
    for (int i = 0; i < recommendations.length; i++) {
      await db.insert('report_recommendations', {
        'reportId': reportId,
        'recommendation': recommendations[i].trim(),
        'displayOrder': i,
      });
    }
  }

  /// Get recommendations for a report from the normalized table
  Future<List<String>> getReportRecommendations(String reportId) async {
    final db = await database;
    
    try {
      final results = await db.query(
        'report_recommendations',
        where: 'reportId = ?',
        whereArgs: [reportId],
        orderBy: 'displayOrder ASC',
      );
      
      return results.map((row) => row['recommendation'] as String).toList();
    } catch (e) {
      // If table doesn't exist yet (old database), fall back to pipe-delimited
      print('⚠️  report_recommendations table not found, attempting migration...');
      return [];
    }
  }

  /// Update recommendations for a report (deletes old ones and inserts new ones)
  Future<void> updateReportRecommendations(String reportId, List<String> recommendations) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Delete existing recommendations
      await txn.delete(
        'report_recommendations',
        where: 'reportId = ?',
        whereArgs: [reportId],
      );
      
      // Insert new recommendations
      for (int i = 0; i < recommendations.length; i++) {
        await txn.insert('report_recommendations', {
          'reportId': reportId,
          'recommendation': recommendations[i].trim(),
          'displayOrder': i,
        });
      }
    });
  }

  /// Delete recommendations when a report is deleted (handled by ON DELETE CASCADE)
  /// This method is for explicit deletion if needed
  Future<void> deleteReportRecommendations(String reportId) async {
    final db = await database;
    await db.delete(
      'report_recommendations',
      where: 'reportId = ?',
      whereArgs: [reportId],
    );
  }
}

