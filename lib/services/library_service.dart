import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/book.dart';
import '../models/shelf.dart';
import 'pdf_storage_service.dart';

class LibraryService {
  LibraryService({AppDatabase? database, PdfStorageService? pdfStorageService})
    : _database = database ?? AppDatabase.instance,
      _pdfStorageService = pdfStorageService ?? PdfStorageService();

  final AppDatabase _database;
  final PdfStorageService _pdfStorageService;

  Future<List<Shelf>> getShelves() async {
    final db = await _database.database;
    final result = await db.query('shelves', orderBy: 'updated_at DESC');

    return result.map(Shelf.fromMap).toList();
  }

  Future<int> createShelf({required String name, String? description}) async {
    final db = await _database.database;
    final now = DateTime.now();

    return db.insert(
      'shelves',
      Shelf(
        name: name,
        description: description,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  }

  Future<void> updateShelf(Shelf shelf) async {
    final db = await _database.database;

    await db.update(
      'shelves',
      shelf.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [shelf.id],
    );
  }

  Future<void> deleteShelf(int shelfId) async {
    final books = await getBooksByShelf(shelfId);

    for (final book in books) {
      if (book.pdfPath != null) {
        await _pdfStorageService.deleteLegacyPdfIfExists(book.pdfPath!);
      }
    }

    final db = await _database.database;
    await db.delete('shelves', where: 'id = ?', whereArgs: [shelfId]);
  }

  Future<List<Book>> getBooksByShelf(int shelfId) async {
    final db = await _database.database;
    final result = await db.query(
      'books',
      where: 'shelf_id = ?',
      whereArgs: [shelfId],
      orderBy: 'updated_at DESC',
    );

    return result.map(Book.fromMap).toList();
  }

  Future<int> createBook({
    required int shelfId,
    required String title,
    String? author,
    required Uint8List pdfData,
    required String fileName,
  }) async {
    final db = await _database.database;
    final now = DateTime.now();

    await db.update(
      'shelves',
      {'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [shelfId],
    );

    return db.insert(
      'books',
      Book(
        shelfId: shelfId,
        title: title,
        author: author,
        pdfData: pdfData,
        fileName: fileName,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  }

  Future<void> updateBook(Book book) async {
    final db = await _database.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'books',
        book.copyWith(updatedAt: now).toMap(),
        where: 'id = ?',
        whereArgs: [book.id],
      );

      await txn.update(
        'shelves',
        {'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [book.shelfId],
      );
    });
  }

  Future<void> replaceBookPdf({
    required Book book,
    required Uint8List newPdfData,
    required String newFileName,
  }) async {
    if (book.pdfPath != null) {
      await _pdfStorageService.deleteLegacyPdfIfExists(book.pdfPath!);
    }

    await updateBook(
      book.copyWith(pdfData: newPdfData, pdfPath: null, fileName: newFileName),
    );
  }

  Future<void> deleteBook(Book book) async {
    if (book.pdfPath != null) {
      await _pdfStorageService.deleteLegacyPdfIfExists(book.pdfPath!);
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete('books', where: 'id = ?', whereArgs: [book.id]);

      await txn.update(
        'shelves',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [book.shelfId],
      );
    });
  }

  Future<bool> databaseLooksValid(Database database) async {
    final tables = await database.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name IN ('shelves', 'books');
    ''');

    if (tables.length != 2) {
      return false;
    }

    final columns = await database.rawQuery('PRAGMA table_info(books);');
    final columnNames = columns.map((column) => column['name']).toSet();

    return columnNames.contains('file_name') &&
        (columnNames.contains('pdf_data') || columnNames.contains('pdf_path'));
  }
}
