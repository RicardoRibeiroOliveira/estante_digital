import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:estante_digital/models/book.dart';
import 'package:estante_digital/models/shelf.dart';

void main() {
  test('converte shelf para map e volta corretamente', () {
    final now = DateTime.now();
    final shelf = Shelf(
      id: 1,
      name: 'Tecnologia',
      description: 'Livros tecnicos',
      createdAt: now,
      updatedAt: now,
    );

    final restored = Shelf.fromMap(shelf.toMap());

    expect(restored.id, 1);
    expect(restored.name, 'Tecnologia');
    expect(restored.description, 'Livros tecnicos');
  });

  test('converte book para map e volta corretamente', () {
    final now = DateTime.now();
    final pdfData = Uint8List.fromList([1, 2, 3, 4]);
    final book = Book(
      id: 1,
      shelfId: 10,
      title: 'Flutter Basico',
      author: 'Autor Exemplo',
      pdfData: pdfData,
      fileName: 'flutter_basico.pdf',
      createdAt: now,
      updatedAt: now,
    );

    final restored = Book.fromMap(book.toMap());

    expect(restored.id, 1);
    expect(restored.shelfId, 10);
    expect(restored.title, 'Flutter Basico');
    expect(restored.hasEmbeddedPdf, isTrue);
    expect(restored.pdfData, pdfData);
  });
}
