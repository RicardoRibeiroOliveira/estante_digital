import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'library_service.dart';
import 'pdf_storage_service.dart';

class ImportDatabaseResult {
  const ImportDatabaseResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class DatabaseBackupService {
  DatabaseBackupService({
    AppDatabase? database,
    LibraryService? libraryService,
    PdfStorageService? pdfStorageService,
  })
    : _database = database ?? AppDatabase.instance,
      _libraryService = libraryService ?? LibraryService(),
      _pdfStorageService = pdfStorageService ?? PdfStorageService();

  final AppDatabase _database;
  final LibraryService _libraryService;
  final PdfStorageService _pdfStorageService;

  Future<String?> exportDatabase() async {
    await _database.database;
    final dbPath = await _database.getDatabasePath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('O banco de dados ainda nao foi criado.');
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final defaultFolderName = 'estante_digital_backup_$timestamp';
    String? backupRootPath;
    String exportedPath;

    if (Platform.isAndroid || Platform.isIOS) {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecionar pasta para exportar backup',
      );
      if (selectedDirectory == null) {
        return null;
      }
      backupRootPath = p.join(selectedDirectory, defaultFolderName);
      exportedPath = backupRootPath;
    } else {
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar banco SQLite',
        fileName: 'estante_digital_backup.db',
        type: FileType.custom,
        allowedExtensions: const ['db'],
      );

      if (targetPath == null) {
        return null;
      }

      final normalizedTarget = p.extension(targetPath).isEmpty
          ? '$targetPath.db'
          : targetPath;
      backupRootPath = p.withoutExtension(normalizedTarget);
      exportedPath = normalizedTarget;
    }

    final backupDirectory = Directory(backupRootPath);
    if (await backupDirectory.exists()) {
      await backupDirectory.delete(recursive: true);
    }
    await backupDirectory.create(recursive: true);

    await _database.close();
    await dbFile.copy(p.join(backupDirectory.path, 'estante_digital_backup.db'));
    await _pdfStorageService.copyLibraryPdfsTo(backupDirectory);
    await _database.database;

    if (!(Platform.isAndroid || Platform.isIOS)) {
      final exportedFile = File(exportedPath);
      await File(
        p.join(backupDirectory.path, 'estante_digital_backup.db'),
      ).copy(exportedFile.path);
    }

    final manifestFile = File(p.join(backupDirectory.path, 'backup_info.txt'));
    await manifestFile.writeAsString(
      'Backup Estante Digital\n'
      'Gerado em: ${DateTime.now().toIso8601String()}\n'
      'Banco: estante_digital_backup.db\n'
      'PDFs: pasta pdfs/\n',
      flush: true,
    );

    if (Platform.isAndroid || Platform.isIOS) {
      return backupDirectory.path;
    }
    return exportedPath;
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
    final importedBackupDirectory = Directory(p.dirname(importedPath));
    final importedPdfDirectory = Directory(
      p.join(importedBackupDirectory.path, 'pdfs'),
    );
    await _pdfStorageService.restoreLibraryPdfsFrom(importedPdfDirectory);

    return const ImportDatabaseResult(
      success: true,
      message: 'Banco importado com sucesso.',
    );
  }
}
