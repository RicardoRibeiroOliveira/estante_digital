import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PdfStorageResult {
  const PdfStorageResult({
    required this.bytes,
    required this.fileName,
    this.filePath,
  });

  final Uint8List bytes;
  final String fileName;
  final String? filePath;
}

class PdfStorageService {
  Future<PdfStorageResult?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );

    final selectedFile = result?.files.single;
    final bytes = selectedFile?.bytes;
    if (selectedFile == null || bytes == null) {
      return null;
    }

    return PdfStorageResult(
      bytes: bytes,
      fileName: selectedFile.name,
      filePath: selectedFile.path,
    );
  }

  Future<String> storePdfInLibrary({
    required String fileName,
    Uint8List? bytes,
    String? sourceFilePath,
  }) async {
    final pdfDirectory = await getPdfLibraryDirectory();
    if (!await pdfDirectory.exists()) {
      await pdfDirectory.create(recursive: true);
    }

    final extension = p.extension(fileName).isEmpty
        ? '.pdf'
        : p.extension(fileName);
    final sanitizedName = p
        .basenameWithoutExtension(fileName)
        .replaceAll(RegExp(r'[^A-Za-z0-9_\\-]'), '_');
    final relativePath = p.join(
      'pdfs',
      '${DateTime.now().millisecondsSinceEpoch}_$sanitizedName$extension',
    );
    final baseDirectory = await getApplicationDocumentsDirectory();
    final targetFile = File(p.join(baseDirectory.path, relativePath));

    if (sourceFilePath != null) {
      await File(sourceFilePath).copy(targetFile.path);
      return relativePath;
    }

    if (bytes == null) {
      throw ArgumentError('Informe os bytes do PDF ou o caminho de origem.');
    }

    await targetFile.writeAsBytes(bytes, flush: true);
    return relativePath;
  }

  Future<Directory> getPdfLibraryDirectory() async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    return Directory(p.join(baseDirectory.path, 'pdfs'));
  }

  Future<void> copyLibraryPdfsTo(Directory targetDirectory) async {
    final sourceDirectory = await getPdfLibraryDirectory();
    if (!await sourceDirectory.exists()) {
      return;
    }

    final backupPdfDirectory = Directory(p.join(targetDirectory.path, 'pdfs'));
    if (!await backupPdfDirectory.exists()) {
      await backupPdfDirectory.create(recursive: true);
    }

    await _copyDirectoryContents(sourceDirectory, backupPdfDirectory);
  }

  Future<void> restoreLibraryPdfsFrom(Directory sourceDirectory) async {
    if (!await sourceDirectory.exists()) {
      return;
    }

    final targetDirectory = await getPdfLibraryDirectory();
    if (await targetDirectory.exists()) {
      await targetDirectory.delete(recursive: true);
    }
    await targetDirectory.create(recursive: true);
    await _copyDirectoryContents(sourceDirectory, targetDirectory);
  }

  Future<Uint8List?> readLegacyPdf(String relativePath) async {
    final file = await _resolveLegacyPdfFile(relativePath);
    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  Future<void> openPdfExternally({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final file = await _createTemporaryPdfFile(
      bytes: bytes,
      fileName: fileName,
    );
    await OpenFilex.open(file.path);
  }

  Future<void> deleteLegacyPdfIfExists(String relativePath) async {
    final file = await _resolveLegacyPdfFile(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _createTemporaryPdfFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final tempDirectory = await getTemporaryDirectory();
    final extension = p.extension(fileName).isEmpty
        ? '.pdf'
        : p.extension(fileName);
    final sanitizedName = p
        .basenameWithoutExtension(fileName)
        .replaceAll(' ', '_');
    final file = File(
      p.join(
        tempDirectory.path,
        '${DateTime.now().millisecondsSinceEpoch}_$sanitizedName$extension',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> _resolveLegacyPdfFile(String relativePath) async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    return File(p.join(baseDirectory.path, relativePath));
  }

  Future<void> _copyDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    await for (final entity in source.list(recursive: false)) {
      final destinationPath = p.join(target.path, p.basename(entity.path));

      if (entity is File) {
        await entity.copy(destinationPath);
        continue;
      }

      if (entity is Directory) {
        final childTarget = Directory(destinationPath);
        if (!await childTarget.exists()) {
          await childTarget.create(recursive: true);
        }
        await _copyDirectoryContents(entity, childTarget);
      }
    }
  }
}
