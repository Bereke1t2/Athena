import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Architecture boundary enforcement (roadmap Phase 3):
/// 1. `package:dio` may only be imported by core/network and feature data/.
/// 2. DTO files (`*.dto.dart`, `*.dtos.dart`) may only be imported from
///    feature data/ layers — they must never leak into presentation/domain.
void main() {
  final libRoot = Directory(p.join(Directory.current.path, 'lib'));
  final dartFiles = <File>[];
  void walk(Directory dir) {
    for (final e in dir.listSync()) {
      if (e is Directory) {
        walk(e);
      } else if (e is File && e.path.endsWith('.dart') && !e.path.endsWith('.g.dart')) {
        dartFiles.add(e);
      }
    }
  }

  setUpAll(() => walk(libRoot));

  test('dio imports stay in core/network and data layers', () {
    final offenders = <String>[];
    for (final f in dartFiles) {
      final rel = p.relative(f.path, from: libRoot.parent.path).replaceAll('\\', '/');
      final allowed = rel.contains('/core/network/') ||
          RegExp(r'/features/[a-z_]+/data/').hasMatch(rel);
      if (!allowed && f.readAsStringSync().contains('package:dio/dio.dart')) {
        offenders.add(rel);
      }
    }
    expect(offenders, isEmpty,
        reason: 'dio leaked outside the network/data layers:\n${offenders.join('\n')}');
  });

  test('DTOs never leak outside the data layer', () {
    final offenders = <String>[];
    final dtoRe =
        RegExp(r"""import\s+['"].*(paper\.dtos\.dart|feed\.dtos\.dart|search\.dtos\.dart|topics_repository_impl\.dart)['"]""");
    for (final f in dartFiles) {
      final rel = p.relative(f.path, from: libRoot.parent.path).replaceAll('\\', '/');
      final allowed = RegExp(r'/features/[a-z_]+/data/').hasMatch(rel) ||
          rel.contains('/core/');
      if (allowed) continue;
      if (dtoRe.hasMatch(f.readAsStringSync())) {
        offenders.add(rel);
      }
    }
    expect(offenders, isEmpty,
        reason: 'DTO/impl imports found above the data layer:\n${offenders.join('\n')}');
  });

  test('domain layer stays framework-free', () {
    final offenders = <String>[];
    final domainFiles = dartFiles.where((f) => f.path.contains('${p.separator}domain${p.separator}'));
    for (final f in domainFiles) {
      final src = f.readAsStringSync();
      if (src.contains('package:flutter/material.dart') ||
          src.contains('package:dio') ||
          src.contains('package:go_router')) {
        offenders.add(p.relative(f.path, from: libRoot.parent.path));
      }
    }
    expect(offenders, isEmpty, reason: 'domain files import frameworks:\n${offenders.join('\n')}');
  });
}
