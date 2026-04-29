import 'package:flutter/material.dart';

import '../../models/shelf.dart';
import '../../services/library_service.dart';

class ShelfFormScreen extends StatefulWidget {
  const ShelfFormScreen({super.key, this.shelf});

  final Shelf? shelf;

  @override
  State<ShelfFormScreen> createState() => _ShelfFormScreenState();
}

class _ShelfFormScreenState extends State<ShelfFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _libraryService = LibraryService();

  bool _isSaving = false;

  bool get _isEditing => widget.shelf != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.shelf?.name ?? '';
    _descriptionController.text = widget.shelf?.description ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    if (_isEditing) {
      await _libraryService.updateShelf(
        widget.shelf!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        ),
      );
    } else {
      await _libraryService.createShelf(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
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
        title: Text(_isEditing ? 'Editar estante' : 'Nova estante'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome da estante'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da estante.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Descricao',
                  alignLabelWithHint: true,
                ),
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
