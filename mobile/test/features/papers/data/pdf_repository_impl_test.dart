import 'dart:io';

import 'package:athena/features/papers/data/pdf_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;
  late Directory docsDir;
  late Directory tempDir;
  late Dio dio;
  late PdfRepositoryImpl repository;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('athena_pdf_test_');
    docsDir = Directory('${testDir.path}/docs')..createSync(recursive: true);
    tempDir = Directory('${testDir.path}/temp')..createSync(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return docsDir.path;
        }
        if (methodCall.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return testDir.path;
      },
    );

    dio = Dio();
    repository = PdfRepositoryImpl(dio);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('PdfRepositoryImpl persistent storage & caching', () {
    test('isCached returns false when no cached PDF exists', () async {
      expect(await repository.isCached('paper-test-1'), isFalse);
      expect(await repository.getCachedPath('paper-test-1'), isNull);
    });

    test('isCached returns true and getCachedPath returns path when file exists in documents', () async {
      final pdfsDir = Directory('${docsDir.path}/pdfs');
      await pdfsDir.create(recursive: true);
      final file = File('${pdfsDir.path}/paper-test-1.pdf');
      await file.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x31]); // %PDF1

      expect(await repository.isCached('paper-test-1'), isTrue);
      expect(await repository.getCachedPath('paper-test-1'), file.path);
    });

    test('download returns cached file immediately without issuing network request', () async {
      final pdfsDir = Directory('${docsDir.path}/pdfs');
      await pdfsDir.create(recursive: true);
      final file = File('${pdfsDir.path}/paper-test-2.pdf');
      await file.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x32]); // %PDF2

      // Non-existent invalid URL; if network were touched it would throw
      final path = await repository.download('paper-test-2', 'http://invalid-url-that-does-not-exist.test/doc.pdf');
      expect(path, file.path);
    });

    test('deleteCache removes the file from persistent documents and temporary cache', () async {
      final pdfsDir = Directory('${docsDir.path}/pdfs');
      await pdfsDir.create(recursive: true);
      final file = File('${pdfsDir.path}/paper-test-3.pdf');
      await file.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x33]);

      expect(await repository.isCached('paper-test-3'), isTrue);

      await repository.deleteCache('paper-test-3');

      expect(await repository.isCached('paper-test-3'), isFalse);
      expect(await file.exists(), isFalse);
      expect(await repository.getCachedPath('paper-test-3'), isNull);
    });

    test('promotes temporary cache file into persistent documents directory', () async {
      final tempPdfsDir = Directory('${tempDir.path}/pdfs');
      await tempPdfsDir.create(recursive: true);
      final tempFile = File('${tempPdfsDir.path}/paper-test-4.pdf');
      await tempFile.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x34]);

      // Verify it's recognized as cached
      expect(await repository.isCached('paper-test-4'), isTrue);

      // Calling download should copy to docs and return the docs path
      final path = await repository.download('paper-test-4', 'http://invalid.test/file.pdf');
      expect(path, contains(docsDir.path));
      expect(await File(path).exists(), isTrue);
    });
  });
}
