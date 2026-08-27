import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../core/error/failure.dart';
import '../../../core/widgets/state_views.dart';

/// In-app PDF reader: downloads (with progress) then renders the paper
/// locally — no browser involved.
class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.paperId,
    required this.url,
    this.title,
  });

  final String paperId;
  final String url;
  final String? title;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  String? _localPath;
  Object? _error;
  int _received = 0;
  int? _total;
  int _retries = 0;
  static const _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    if (widget.url.isEmpty) {
      _error = const Failure.unknown(cause: 'No PDF URL available for this paper');
    } else {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    try {
      final path = await ref.read(pdfRepositoryProvider).download(
            widget.paperId,
            widget.url,
            onProgress: (r, t) {
              if (!mounted) return;
              setState(() {
                _received = r;
                _total = t;
              });
            },
          );
      if (!mounted) return;
      setState(() => _localPath = path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? 'PDF',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _error != null
          ? ErrorView(
              failure: _error!,
              onRetry: () {
                setState(() {
                  _error = null;
                  _received = 0;
                  _total = null;
                  _retries = 0;
                });
                _fetch();
              },
            )
          : _localPath == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      if (_total != null && _total! > 0) ...[
                        SizedBox(
                          width: 220,
                          child: LinearProgressIndicator(value: _received / _total!),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        _total != null && _total! > 0
                            ? 'Downloading… ${(_received / 1048576).toStringAsFixed(1)} / ${(_total! / 1048576).toStringAsFixed(1)} MB'
                            : 'Downloading PDF…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  nightMode: theme.brightness == Brightness.dark,
                  onError: (e) {
                    unawaited(ref.read(pdfRepositoryProvider).deleteCache(widget.paperId));
                    if (!mounted) return;
                    if (_retries < _maxRetries) {
                      _retries++;
                      setState(() {
                        _localPath = null;
                        _error = null;
                        _received = 0;
                        _total = null;
                      });
                      _fetch();
                    } else {
                      setState(() => _error = const Failure.unknown(cause: 'Failed to load PDF after retries'));
                    }
                  },
                ),
    );
  }
}
