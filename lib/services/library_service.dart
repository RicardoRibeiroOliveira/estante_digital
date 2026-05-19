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
      columns: const [
        'id',
        'shelf_id',
        'title',
        'author',
        'pdf_path',
        'file_name',
        'created_at',
        'updated_at',
      ],
      where: 'shelf_id = ?',
      whereArgs: [shelfId],
      orderBy: 'updated_at DESC',
    );

    final books = result.map(Book.fromMap).toList();
    final embeddedIds = await db.rawQuery(
      '''
      SELECT id
      FROM books
      WHERE shelf_id = ? AND pdf_data IS NOT NULL
      ''',
      [shelfId],
    );
    final idsWithEmbeddedPdf = embeddedIds
        .map((row) => row['id'] as int)
        .toSet();

    return books
        .map(
          (book) => book.copyWith(
            hasEmbeddedPdfData: idsWithEmbeddedPdf.contains(book.id),
          ),
        )
        .toList();
  }

  Future<Book?> getBookById(int id) async {
    final db = await _database.database;
    final result = await db.query(
      'books',
      columns: const [
        'id',
        'shelf_id',
        'title',
        'author',
        'pdf_path',
        'file_name',
        'created_at',
        'updated_at',
      ],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    final embeddedPdfExists = await db.rawQuery(
      'SELECT id FROM books WHERE id = ? AND pdf_data IS NOT NULL LIMIT 1',
      [id],
    );

    return Book.fromMap(
      result.first,
    ).copyWith(hasEmbeddedPdfData: embeddedPdfExists.isNotEmpty);
  }

  Future<Uint8List?> getEmbeddedPdfData(int id) async {
    final db = await _database.database;
    const chunkSize = 512 * 1024;
    final buffer = BytesBuilder(copy: false);
    var start = 1;

    while (true) {
      final result = await db.rawQuery(
        '''
        SELECT substr(pdf_data, ?, ?) AS chunk
        FROM books
        WHERE id = ? AND pdf_data IS NOT NULL
        LIMIT 1
        ''',
        [start, chunkSize, id],
      );

      if (result.isEmpty) {
        return buffer.length == 0 ? null : buffer.takeBytes();
      }

      final chunk = result.first['chunk'] as Uint8List?;
      if (chunk == null || chunk.isEmpty) {
        return buffer.length == 0 ? null : buffer.takeBytes();
      }

      buffer.add(chunk);
      if (chunk.length < chunkSize) {
        return buffer.takeBytes();
      }

      start += chunkSize;
    }
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
        hasEmbeddedPdfData: true,
        pdfPath: null,
        fileName: fileName,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  }

  Future<void> updateBook(Book book) async {
    final db = await _database.database;
    final now = DateTime.now();
    final updateMap = book.copyWith(updatedAt: now).toMap()..remove('id');

    if (book.hasEmbeddedPdfData && book.pdfData == null) {
      updateMap.remove('pdf_data');
    }

    await db.transaction((txn) async {
      await txn.update(
        'books',
        updateMap,
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
      book.copyWith(
        pdfData: newPdfData,
        hasEmbeddedPdfData: true,
        pdfPath: null,
        fileName: newFileName,
      ),
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

  Future<int> embedLegacyPdfsIntoDatabase() async {
    final db = await _database.database;
    final legacyBooks = await db.query(
      'books',
      columns: const ['id', 'pdf_path'],
      where:
          'pdf_path IS NOT NULL AND (pdf_data IS NULL OR length(pdf_data) = 0)',
    );

    var embeddedCount = 0;

    for (final row in legacyBooks) {
      final bookId = row['id'] as int?;
      final pdfPath = row['pdf_path'] as String?;
      if (bookId == null || pdfPath == null || pdfPath.isEmpty) {
        continue;
      }

      final bytes = await _pdfStorageService.readLegacyPdf(pdfPath);
      if (bytes == null || bytes.isEmpty) {
        continue;
      }

      await db.update(
        'books',
        {
          'pdf_data': bytes,
          'pdf_path': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [bookId],
      );
      embeddedCount++;
    }

    return embeddedCount;
  }
}
