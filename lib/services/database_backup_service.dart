import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'library_service.dart';

class ImportDatabaseResult {
  const ImportDatabaseResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class DatabaseBackupService {
  DatabaseBackupService({AppDatabase? database, LibraryService? libraryService})
    : _database = database ?? AppDatabase.instance,
      _libraryService = libraryService ?? LibraryService();

  final AppDatabase _database;
  final LibraryService _libraryService;

  Future<String?> exportDatabase() async {
    await _database.database;
    await _libraryService.embedLegacyPdfsIntoDatabase();
    final dbPath = await _database.getDatabasePath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('O banco de dados ainda nao foi criado.');
    }

    await _database.close();

    try {
      final databaseBytes = await dbFile.readAsBytes();
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar banco SQLite',
        fileName: 'estante_digital_backup.db',
        type: FileType.custom,
        allowedExtensions: const ['db'],
        bytes: databaseBytes,
      );

      return targetPath;
    } finally {
      await _database.database;
    }
  }

  Future<ImportDatabaseResult> importDatabase() async {
    await _database.database;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecionar banco SQLite',
      type: FileType.custom,
      allowedExtensions: const ['db', 'sqlite', 'sqlite3'],
    );

    final importedPath = result?.files.single.path;
    if (importedPath == null) {
      return const ImportDatabaseResult(
        success: false,
        message: 'Importacao cancelada.',
      );
    }

    Database? validationDatabase;

    try {
      validationDatabase = await openDatabase(
        importedPath,
        readOnly: true,
        singleInstance: false,
      );

      final isValid = await _libraryService.databaseLooksValid(
        validationDatabase,
      );

      if (!isValid) {
        return const ImportDatabaseResult(
          success: false,
          message: 'O arquivo selecionado nao contem as tabelas esperadas.',
        );
      }
    } catch (_) {
      return const ImportDatabaseResult(
        success: false,
        message: 'O arquivo informado nao e um banco SQLite valido.',
      );
    } finally {
      await validationDatabase?.close();
    }

    await _database.replaceDatabaseWith(File(importedPath));

    return const ImportDatabaseResult(
      success: true,
      message: 'Banco importado com sucesso.',
    );
  }
}
