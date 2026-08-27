import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/pdf_repository.dart';

/// PDF access backed by dio downloads into the app cache directory.
class PdfRepositoryImpl implements PdfRepository {
  PdfRepositoryImpl(this._dio);

  final Dio _dio;

  static const _downloadTimeout = Duration(minutes: 5);

  /// Returns a cached local path for [url], downloading on first use.
  /// Progress is reported as (received, total-or-null) bytes.
  @override
  Future<String> download(String paperId, String url,
      {void Function(int received, int? total)? onProgress}) async {
    final file = await _localFile(paperId);
    if (await file.exists() && await file.length() > 0) return file.path;

    try {
      final res = await _dio.download(
        url,
        file.path,
        options: Options(
          receiveTimeout: _downloadTimeout,
          followRedirects: true,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Mobile; Athena/1.0)',
          },
          validateStatus: (s) => s != null && s >= 200 && s < 400,
        ),
        onReceiveProgress: onProgress,
      );

      // Verify it's actually a PDF — reject HTML error pages / landing pages.
      final contentType = res.headers.value('content-type') ?? '';
      if (contentType.contains('text/html')) {
        await file.delete();
        throw const Failure.unknown(cause: 'The link points to a web page, not a PDF file.');
      }

      final raf = await file.open();
      final header = await raf.read(4);
      await raf.close();
      if (header.length < 4 || String.fromCharCodes(header) != '%PDF') {
        throw const Failure.unknown(cause: 'Downloaded file is not a valid PDF.');
      }
    } catch (e) {
      // Don't leave partial files behind.
      if (await file.exists()) await file.delete();
      if (e is Failure) rethrow;
      throw failureFromDio(e);
    }
    return file.path;
  }

  Future<File> _localFile(String paperId) async {
    final dir = await getTemporaryDirectory();
    final pdfs = Directory('${dir.path}/pdfs');
    if (!await pdfs.exists()) await pdfs.create(recursive: true);
    return File('${pdfs.path}/$paperId.pdf');
  }

  @override
  Future<void> deleteCache(String paperId) async {
    final file = await _localFile(paperId);
    if (await file.exists()) await file.delete();
  }
}
