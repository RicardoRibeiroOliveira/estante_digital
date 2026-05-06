import 'dart:typed_data';

const _unsetValue = Object();

class Book {
  const Book({
    this.id,
    required this.shelfId,
    required this.title,
    this.author,
    this.pdfData,
    this.hasEmbeddedPdfData = false,
    this.pdfPath,
    required this.fileName,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int shelfId;
  final String title;
  final String? author;
  final Uint8List? pdfData;
  final bool hasEmbeddedPdfData;
  final String? pdfPath;
  final String fileName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shelf_id': shelfId,
      'title': title,
      'author': author,
      'pdf_data': pdfData,
      'pdf_path': pdfPath,
      'file_name': fileName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      shelfId: map['shelf_id'] as int,
      title: map['title'] as String,
      author: map['author'] as String?,
      pdfData: map['pdf_data'] as Uint8List?,
      hasEmbeddedPdfData:
          (map['has_embedded_pdf_data'] as int?) == 1 ||
          map['pdf_data'] != null,
      pdfPath: map['pdf_path'] as String?,
      fileName: map['file_name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Book copyWith({
    int? id,
    int? shelfId,
    String? title,
    String? author,
    Object? pdfData = _unsetValue,
    bool? hasEmbeddedPdfData,
    Object? pdfPath = _unsetValue,
    String? fileName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      shelfId: shelfId ?? this.shelfId,
      title: title ?? this.title,
      author: author ?? this.author,
      pdfData: identical(pdfData, _unsetValue)
          ? this.pdfData
          : pdfData as Uint8List?,
      hasEmbeddedPdfData: hasEmbeddedPdfData ?? this.hasEmbeddedPdfData,
      pdfPath: identical(pdfPath, _unsetValue)
          ? this.pdfPath
          : pdfPath as String?,
      fileName: fileName ?? this.fileName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasEmbeddedPdf =>
      (pdfData != null && pdfData!.isNotEmpty) || hasEmbeddedPdfData;
}
