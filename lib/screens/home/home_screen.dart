import 'package:flutter/material.dart';

import '../../models/shelf.dart';
import '../../services/database_backup_service.dart';
import '../../services/library_service.dart';
import '../../widgets/empty_state_card.dart';
import '../books/books_screen.dart';
import '../shelves/shelf_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _libraryService = LibraryService();
  final _backupService = DatabaseBackupService();

  late Future<List<Shelf>> _shelvesFuture;

  @override
  void initState() {
    super.initState();
    _loadShelves();
  }

  void _loadShelves() {
    setState(() {
      _shelvesFuture = _libraryService.getShelves();
    });
  }

  Future<void> _openShelfForm([Shelf? shelf]) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ShelfFormScreen(shelf: shelf)));

    _loadShelves();
  }

  Future<void> _deleteShelf(Shelf shelf) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir estante'),
        content: Text(
          'Deseja excluir a estante "${shelf.name}" e seus livros?',
        ),
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

    await _libraryService.deleteShelf(shelf.id!);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estante excluida com sucesso.')),
    );
    _loadShelves();
  }

  Future<void> _exportDatabase() async {
    try {
      final path = await _backupService.exportDatabase();
      if (!mounted || path == null) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Banco exportado para: $path')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _importDatabase() async {
    final result = await _backupService.importDatabase();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));

    if (result.success) {
      _loadShelves();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estante Digital'),
        actions: [
          IconButton(
            tooltip: 'Importar banco',
            onPressed: _importDatabase,
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Exportar banco',
            onPressed: _exportDatabase,
            icon: const Icon(Icons.upload_file_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openShelfForm,
        icon: const Icon(Icons.add),
        label: const Text('Nova estante'),
      ),
      body: FutureBuilder<List<Shelf>>(
        future: _shelvesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: EmptyStateCard(
                icon: Icons.error_outline,
                title: 'Nao foi possivel carregar as estantes',
                message: snapshot.error.toString(),
              ),
            );
          }

          final shelves = snapshot.data ?? [];
          if (shelves.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Sua biblioteca esta vazia',
                  message:
                      'Crie a primeira estante para comecar a organizar seus PDFs.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemBuilder: (context, index) {
              final shelf = shelves[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(shelf.name),
                  subtitle: Text(
                    shelf.description?.isNotEmpty == true
                        ? shelf.description!
                        : 'Sem descricao',
                  ),
                  leading: const CircleAvatar(child: Icon(Icons.book_outlined)),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BooksScreen(shelf: shelf),
                      ),
                    );

                    _loadShelves();
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openShelfForm(shelf);
                          break;
                        case 'delete':
                          _deleteShelf(shelf);
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
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: shelves.length,
          );
        },
      ),
    );
  }
}
