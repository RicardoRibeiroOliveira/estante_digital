import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/shelf.dart';
import '../../services/library_service.dart';
import '../../widgets/empty_state_card.dart';
import 'book_form_screen.dart';
import 'pdf_viewer_screen.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key, required this.shelf});

  final Shelf shelf;

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final _libraryService = LibraryService();

  late Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() {
    setState(() {
      _booksFuture = _libraryService.getBooksByShelf(widget.shelf.id!);
    });
  }

  Future<void> _openBookForm([Book? book]) async {
    Book? bookForEditing = book;
    if (book != null) {
      bookForEditing = await _libraryService.getBookById(book.id!);
      if (bookForEditing == null) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel localizar o livro.')),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BookFormScreen(shelf: widget.shelf, book: bookForEditing),
      ),
    );

    _loadBooks();
  }

  Future<void> _openPdfViewer(Book book) async {
    final fullBook = await _libraryService.getBookById(book.id!);
    if (!mounted) {
      return;
    }

    if (fullBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel localizar o PDF.')),
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PdfViewerScreen(book: fullBook)));
  }

  Future<void> _deleteBook(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir livro'),
        content: Text('Deseja excluir o livro "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    await _libraryService.deleteBook(book);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Livro excluido com sucesso.')),
    );
    _loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.shelf.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBookForm,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Adicionar PDF'),
      ),
      body: FutureBuilder<List<Book>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: EmptyStateCard(
                icon: Icons.error_outline,
                title: 'Nao foi possivel carregar os livros',
                message: snapshot.error.toString(),
              ),
            );
          }

          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Nenhum PDF nesta estante',
                  message: 'Adicione um arquivo PDF para comecar.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final book = books[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () => _openPdfViewer(book),
                  leading: const CircleAvatar(
                    child: Icon(Icons.menu_book_rounded),
                  ),
                  title: Text(book.title),
                  subtitle: Text(
                    [
                      if (book.author?.isNotEmpty == true) book.author!,
                      book.fileName,
                    ].join(' | '),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openBookForm(book);
                          break;
                        case 'delete':
                          _deleteBook(book);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
