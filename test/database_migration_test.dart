import 'package:flutter_test/flutter_test.dart';
import 'package:integriscan/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database migration - deleted column', () {
    late String dbPath;

    setUp(() async {
      // Initialize sqflite ffi for unit tests (Dart VM)
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      // Create a temporary databases path to isolate test DB
  final databasesPath = await getDatabasesPath();
  dbPath = path.join(databasesPath, 'test_app_database.db');

      // Ensure any previous test DB removed
      if (await databaseExists(dbPath)) {
        await deleteDatabase(dbPath);
      }

      // Create a DB with an older schema (simulate missing 'deleted' column)
      // Open with version 8 so that when DatabaseHelper opens it, onUpgrade won't attempt to recreate tables
      final db = await openDatabase(
        dbPath,
        version: 8,
        onCreate: (Database db, int version) async {
          // Create reports table without 'deleted'
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
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      );

      await db.close();
    });

    tearDown(() async {
      // Clean up test DB
      if (await databaseExists(dbPath)) {
        await deleteDatabase(dbPath);
      }
    });

    test('migration adds deleted column and allows insert', () async {
      // Point DatabaseHelper to the test DB path by creating a database file in the standard location
      // DatabaseHelper uses getDatabasesPath + 'app_database.db' by default; we'll copy our test DB there
  final standardPath = path.join(await getDatabasesPath(), 'app_database.db');

      // Ensure any existing app DB is removed for isolation
      if (await databaseExists(standardPath)) {
        await deleteDatabase(standardPath);
      }

      // Copy our test DB to the expected name
  final src = path.join(await getDatabasesPath(), 'test_app_database.db');
  final dst = standardPath;
      if (await File(src).exists()) {
        await File(src).copy(dst);
      }

      final dbHelper = DatabaseHelper();

      // Opening db via helper should trigger _ensureDeletedColumnExists
      final db = await dbHelper.database;

      // Attempt to insert a simple report map - using minimal required fields
      final report = {
        'id': 'test-report-1',
        'userId': 'user-1',
        'sessionName': 'test-session',
        'createdAt': DateTime.now().toIso8601String(),
        'detectionsCount': 0,
        'severityLevel': 'Low',
        'recommendations': '',
        'cracksCount': 0,
        'corrosionCount': 0,
        'deformationCount': 0,
        'synced': 0,
      };

      // Should not throw despite original DB missing 'deleted' column
      await dbHelper.insertReport(report);

      // Verify the report now exists
      final fetched = await dbHelper.getReport('test-report-1');
      expect(fetched, isNotNull);
      expect(fetched!['id'], equals('test-report-1'));

      // Also verify the deleted column exists and is 0 by default
      final pragma = await db.rawQuery("PRAGMA table_info(reports)");
      final hasDeleted = pragma.any((c) => c['name'] == 'deleted');
      expect(hasDeleted, isTrue);

      final row = (await db.query('reports', where: 'id = ?', whereArgs: ['test-report-1'])).first;
      expect(row['deleted'] ?? 0, equals(0));

      await db.close();
    });
  });
}
