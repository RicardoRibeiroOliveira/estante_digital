import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/shelf.dart';
import '../../services/library_service.dart';
import '../../services/pdf_storage_service.dart';

class BookFormScreen extends StatefulWidget {
  const BookFormScreen({super.key, required this.shelf, this.book});

  final Shelf shelf;
  final Book? book;

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _libraryService = LibraryService();
  final _pdfStorageService = PdfStorageService();

  bool _isSaving = false;
  Uint8List? _selectedPdfData;
  String? _legacyPdfPath;
  String? _selectedFileName;

  bool get _isEditing => widget.book != null;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.book?.title ?? '';
    _authorController.text = widget.book?.author ?? '';
    _selectedPdfData = widget.book?.pdfData;
    _legacyPdfPath = widget.book?.pdfPath;
    _selectedFileName = widget.book?.fileName;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await _pdfStorageService.pickPdf();
    if (result == null) {
      return;
    }

    setState(() {
      _selectedPdfData = result.bytes;
      _legacyPdfPath = null;
      _selectedFileName = result.fileName;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if ((_selectedPdfData == null && _legacyPdfPath == null) ||
        _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um arquivo PDF.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    if (_isEditing) {
      final updatedBook = widget.book!.copyWith(
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
      );

      final pdfWasChanged =
          _legacyPdfPath != widget.book!.pdfPath ||
          !listEquals(_selectedPdfData, widget.book!.pdfData) ||
          _selectedFileName != widget.book!.fileName;

      if (pdfWasChanged) {
        await _libraryService.replaceBookPdf(
          book: updatedBook,
          newPdfData: _selectedPdfData!,
          newFileName: _selectedFileName!,
        );
      } else {
        await _libraryService.updateBook(updatedBook);
      }
    } else {
      await _libraryService.createBook(
        shelfId: widget.shelf.id!,
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        pdfData: _selectedPdfData!,
        fileName: _selectedFileName!,
      );
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar livro' : 'Novo livro PDF'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titulo'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o titulo do livro.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(labelText: 'Autor'),
              ),
              const SizedBox(height: 20),
              Text(
                _selectedFileName ?? 'Nenhum PDF selecionado',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_isEditing &&
                  widget.book?.hasEmbeddedPdf == false &&
                  widget.book?.pdfPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Este livro ainda usa o PDF antigo fora do banco. Ao exportar, o app tentara incorporar esse PDF automaticamente no banco.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPdf,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(_isEditing ? 'Trocar PDF' : 'Selecionar PDF'),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Salvando...' : 'Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
