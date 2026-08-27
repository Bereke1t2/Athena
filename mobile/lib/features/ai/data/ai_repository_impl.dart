import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/ai_models.dart';
import '../domain/ai_repository.dart';

String _failureText(Object e) => switch (failureFromDio(e)) {
      final ValidationFailure f => f.message,
      final NotFoundFailure f => f.message ?? 'not found',
      final ServerFailure f => f.message ?? 'server error',
      _ => 'request failed',
    };

/// Hand-rolled DTO parsing (wire shapes are snake_case per API spec).
class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl(this._dio);

  final Dio _dio;

  // AI calls (PDF indexing + generation) can legitimately run long.
  static const _aiTimeout = Duration(minutes: 3);

  @override
  Future<PaperSummaryAI> summarize(String paperId, ExplanationLevel level) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/research/papers/$paperId/summary',
        data: {'level': level.wireValue},
        options: Options(receiveTimeout: _aiTimeout),
      );
      final b = res.data!;
      return PaperSummaryAI(
        paperId: b['paper_id'] as String,
        level: explanationLevelFromWire(b['level'] as String?) ?? level,
        tldr: (b['tldr'] ?? '') as String,
        sections: SummarySections(
          simpleExplanation: (b['sections']?['simple_explanation'] ?? '') as String,
          academicExplanation: (b['sections']?['academic_explanation'] ?? '') as String,
          keyFindings:
              (b['sections']?['key_findings'] as List<dynamic>? ?? const [])
                  .cast<String>(),
          methodology: (b['sections']?['methodology'] ?? '') as String,
          results: (b['sections']?['results'] ?? '') as String,
          limitations:
              (b['sections']?['limitations'] as List<dynamic>? ?? const [])
                  .cast<String>(),
          whyItMatters: (b['sections']?['why_it_matters'] ?? '') as String,
        ),
        grounding: Grounding(
          basedOn: (b['based_on'] ?? 'abstract') as String,
          chunkCount: (b['chunk_count'] ?? 0) as int,
        ),
        cacheHit: (b['cache_hit'] ?? false) as bool,
        modelId: (b['model_id'] ?? '') as String,
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<String> createSession(String paperId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/chat/sessions',
        data: {'paper_id': paperId},
      );
      return res.data!['id'] as String;
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<List<ChatMessage>> messages(String sessionId) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/chat/sessions/$sessionId/messages',
      );
      return res.data!.map(_messageFromJson).toList();
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Stream<ChatStreamEvent> ask(String sessionId, String content) async* {
    final ResponseBody body;
    try {
      final res = await _dio.post<ResponseBody>(
        '/chat/sessions/$sessionId/messages',
        data: {'content': content},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: _aiTimeout,
        ),
      );
      body = res.data!;
    } catch (e) {
      yield ChatFailed(_failureText(e));
      return;
    }

    final controller = StreamController<ChatStreamEvent>();
    late StreamSubscription<String> sub;
    final sseBuffer = StringBuffer();
    sub = body.stream.cast<List<int>>().transform(utf8.decoder).listen(
      (chunk) {
        sseBuffer.write(chunk.replaceAll('\r\n', '\n'));
        final raw = sseBuffer.toString();
        final lastDoubleNewline = raw.lastIndexOf('\n\n');
        if (lastDoubleNewline == -1) return;
        sseBuffer.clear();
        sseBuffer.write(raw.substring(lastDoubleNewline + 2));
        _parseSse(raw.substring(0, lastDoubleNewline + 2), controller.add);
      },
      onError: (Object e) async {
        controller.add(const ChatFailed('connection lost'));
        await controller.close();
      },
      onDone: () async {
        final remaining = sseBuffer.toString().trim();
        if (remaining.isNotEmpty) _parseSse(remaining, controller.add);
        await sub.cancel();
        await controller.close();
      },
    );
    yield* controller.stream;
  }

  // ---- SSE parsing ----------------------------------------------------------

  void _parseSse(String text, void Function(ChatStreamEvent) emit) {
    for (final frame in text.split('\n\n')) {
      for (final line in frame.split('\n')) {
        if (!line.startsWith('data:')) continue;
        final raw = line.substring(5).trim();
        if (raw.isEmpty) continue;
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          switch (json['type']) {
            case 'delta':
              emit(ChatDelta((json['text'] ?? '') as String));
            case 'done':
              emit(ChatDone(_messageFromJson(json['message'])));
            case 'error':
              emit(ChatFailed((json['message'] ?? 'generation failed') as String));
          }
        } on FormatException {
          // tolerate partial/malformed frames
        }
      }
    }
  }

  ChatMessage _messageFromJson(dynamic raw) {
    final json = (raw as Map).cast<String, dynamic>();
    final citations = (json['citations'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((c) => c.cast<String, dynamic>())
        .map((c) => ChatCitation(
              chunkId: (c['chunk_id'] ?? '') as String,
              sectionPath: (c['section_path'] ?? '') as String,
              quote: (c['quote'] ?? '') as String,
            ))
        .toList();
    DateTime? createdAt;
    if (json['created_at'] is String) {
      createdAt = DateTime.tryParse(json['created_at'] as String);
    }
    return ChatMessage(
      id: (json['id'] ?? '') as String,
      role: (json['role'] ?? 'assistant') as String,
      content: (json['content'] ?? '') as String,
      citations: citations,
      createdAt: createdAt,
    );
  }
}
