import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PdfStorageResult {
  const PdfStorageResult({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
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

    return PdfStorageResult(bytes: bytes, fileName: selectedFile.name);
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
}
