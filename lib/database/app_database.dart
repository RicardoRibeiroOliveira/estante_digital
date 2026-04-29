import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _databaseName = 'estante_digital.db';
  static const _databaseVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await getDatabasePath();
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE books ADD COLUMN pdf_data BLOB;');
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE shelves (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shelf_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        author TEXT,
        pdf_data BLOB,
        pdf_path TEXT,
        file_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (shelf_id) REFERENCES shelves(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX idx_books_shelf_id ON books (shelf_id);');
  }

  Future<String> getDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, _databaseName);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> replaceDatabaseWith(File sourceFile) async {
    await close();
    final targetPath = await getDatabasePath();
    final targetFile = File(targetPath);

    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    await sourceFile.copy(targetPath);
    _database = await _openDatabase();
  }
}
