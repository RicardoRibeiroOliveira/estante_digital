
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/book.dart';
import '../../services/library_service.dart';
import '../../services/pdf_storage_service.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.book});

  final Book book;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _pdfStorageService = PdfStorageService();
  final _libraryService = LibraryService();
  late Future<_PdfSource> _pdfSourceFuture;

  @override
  void initState() {
    super.initState();
    _pdfSourceFuture = _resolvePdfSource();
  }

  Future<_PdfSource> _resolvePdfSource() async {
    var book = widget.book;

    if (book.hasEmbeddedPdf && (book.pdfData == null || book.pdfData!.isEmpty)) {
      final bookId = book.id;
      if (bookId != null) {
        final fullBook = await _libraryService.getBookById(bookId);
        if (fullBook != null) {
          book = fullBook;
        }
        final bytes = await _libraryService.getEmbeddedPdfData(bookId);
        if (bytes != null) {
          return _PdfSource(bytes: bytes, fileName: book.fileName);
        }
      }
    }

    if (book.pdfData != null && book.pdfData!.isNotEmpty) {
      return _PdfSource(bytes: book.pdfData!, fileName: book.fileName);
    }

    if (book.pdfPath != null) {
      final bytes = await _pdfStorageService.readLegacyPdf(book.pdfPath!);
      if (bytes != null) {
        return _PdfSource(
          bytes: bytes,
          fileName: book.fileName,
        );
      }
    }

    throw Exception('PDF nao encontrado.');
  }

  Future<void> _openExternally(_PdfSource source) async {
    await _pdfStorageService.openPdfExternally(
      bytes: source.bytes,
      fileName: source.fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title)),
      body: FutureBuilder<_PdfSource>(
        future: _pdfSourceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Nao foi possivel localizar o PDF deste livro.'),
            );
          }

          final source = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        source.fileName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openExternally(source),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir externamente'),
                    ),
                  ],
                ),
              ),
              Expanded(child: SfPdfViewer.memory(source.bytes)),
            ],
          );
        },
      ),
    );
  }
}

class _PdfSource {
  const _PdfSource({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}
