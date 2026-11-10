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
  });
}
