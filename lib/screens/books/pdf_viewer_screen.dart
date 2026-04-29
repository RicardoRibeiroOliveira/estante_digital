import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/book.dart';
import '../../services/pdf_storage_service.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.book});

  final Book book;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _pdfStorageService = PdfStorageService();
  late Future<_PdfSource> _pdfSourceFuture;

  @override
  void initState() {
    super.initState();
    _pdfSourceFuture = _resolvePdfSource();
  }

  Future<_PdfSource> _resolvePdfSource() async {
    if (widget.book.hasEmbeddedPdf) {
      return _PdfSource(
        bytes: widget.book.pdfData!,
        fileName: widget.book.fileName,
      );
    }

    if (widget.book.pdfPath != null) {
      final file = await _pdfStorageService.resolveLegacyPdfFile(
        widget.book.pdfPath!,
      );
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return _PdfSource(
          bytes: bytes,
          fileName: widget.book.fileName,
          file: file,
        );
      }
    }

    throw Exception('PDF nao encontrado.');
  }

  Future<void> _openExternally(_PdfSource source) async {
    final file =
        source.file ??
        await _pdfStorageService.createTemporaryPdfFile(
          bytes: source.bytes,
          fileName: source.fileName,
        );
    await OpenFilex.open(file.path);
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
  const _PdfSource({required this.bytes, required this.fileName, this.file});

  final Uint8List bytes;
  final String fileName;
  final File? file;
}
