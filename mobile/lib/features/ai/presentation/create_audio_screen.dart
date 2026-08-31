import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_branding.dart';
import '../../papers/domain/audio_playback.dart';
import '../../papers/presentation/audio_player_notifier.dart';
import '../../papers/presentation/paper_audio_player_screen.dart';
import 'user_credits_notifier.dart';

/// Screen 3: Create Audio / Research Synthesis Studio Screen
class CreateAudioScreen extends ConsumerStatefulWidget {
  const CreateAudioScreen({super.key});

  @override
  ConsumerState<CreateAudioScreen> createState() => _CreateAudioScreenState();
}

class _CreateAudioScreenState extends ConsumerState<CreateAudioScreen> {
  final _urlController = TextEditingController(text: 'https://arxiv.org/abs/2403.12345');
  final _notesController = TextEditingController();
  int _selectedSource = 0; // 0: Link, 1: PDF, 2: Notes, 3: Voice
  String _selectedVoice = 'Mara';
  String _selectedLength = 'Standard · 12m';
  String? _selectedPdfName = 'neural_scaling_laws.pdf (2.4 MB)';
  bool _isRecording = false;
  int _recordedSeconds = 0;
  bool _isGenerating = false;
  String _generationStep = '';

  @override
  void dispose() {
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _requiredCredits {
    if (_selectedLength.startsWith('Brief')) return 1;
    if (_selectedLength.startsWith('Standard')) return 2;
    return 3;
  }

  String get _lengthStats {
    if (_selectedLength.startsWith('Brief')) return '~5 min · 1,020 words · English';
    if (_selectedLength.startsWith('Standard')) return '~12 min · 2,450 words · English';
    return '~25 min · 5,100 words · English';
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!;
      });
    }
  }

  Future<void> _startGeneration() async {
    final credits = ref.read(userCreditsProvider);
    if (credits < _requiredCredits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need $_requiredCredits credits, but you have $credits.'),
          backgroundColor: const Color(0xFFFF7675),
        ),
      );
      return;
    }

    String title = 'Synthesized Research Brief';
    if (_selectedSource == 0 && _urlController.text.isNotEmpty) {
      title = 'Synthesis: ${_urlController.text.split('/').last}';
    } else if (_selectedSource == 1 && _selectedPdfName != null) {
      title = 'Synthesis: ${_selectedPdfName!.split(' ').first}';
    } else if (_selectedSource == 2 && _notesController.text.isNotEmpty) {
      title = _notesController.text.split('\n').first.take(30);
    } else if (_selectedSource == 3) {
      title = 'Voice Memo Synthesis';
    }

    setState(() {
      _isGenerating = true;
      _generationStep = 'Extracting key findings & semantic structure…';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _generationStep = 'Generating voice narration with $_selectedVoice…';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    ref.read(userCreditsProvider.notifier).deduct(_requiredCredits);

    final newTrack = AudioTrack(
      id: 'gen-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      authorVenue: 'AI Audio Synthesis · $_selectedVoice · $_selectedLength',
      totalDuration: _selectedLength.startsWith('Brief')
          ? const Duration(minutes: 5)
          : (_selectedLength.startsWith('Standard')
              ? const Duration(minutes: 12)
              : const Duration(minutes: 25)),
      chapters: [
        const AudioChapter(
          index: 1,
          title: '01 Overview & Core Claims',
          startOffset: Duration.zero,
          duration: Duration(minutes: 3, seconds: 30),
        ),
        const AudioChapter(
          index: 2,
          title: '02 Technical Deep Dive',
          startOffset: Duration(minutes: 3, seconds: 30),
          duration: Duration(minutes: 5, seconds: 0),
        ),
        const AudioChapter(
          index: 3,
          title: '03 Key Takeaways & Action Items',
          startOffset: Duration(minutes: 8, seconds: 30),
          duration: Duration(minutes: 3, seconds: 30),
        ),
      ],
      takeaways: const [
        'Multi-modal input structures yield high conceptual compression with zero retention loss.',
        'Audio narration enables asynchronous digestion during commuting and deep focus routines.',
      ],
      pullQuote: AudioQuote(
        quote: 'Knowledge synthesis accelerates retention through focused audio immersion.',
        context: 'Synthesis output · $_selectedVoice',
        timestamp: const Duration(minutes: 1, seconds: 15),
      ),
      tags: ['Custom Synthesis', _selectedVoice, _selectedLength.split(' ').first],
      gradientThemeIndex: 3,
    );

    ref.read(audioPlayerProvider.notifier).playTrack(newTrack);

    setState(() {
      _isGenerating = false;
    });

    if (mounted) {
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const PaperAudioPlayerScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final credits = ref.watch(userCreditsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Create audio',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMPORT FROM Header
              AnimatedEntrance(
                delay: const Duration(milliseconds: 50),
                child: Text(
                  'SYNTHESIS SOURCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 2x2 Grid Cards
              AnimatedEntrance(
                delay: const Duration(milliseconds: 100),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ImportCard(
                            num: '01',
                            title: 'arXiv / DOI link',
                            subtitle: 'ArXiv, Nature, OpenAlex, Crossref',
                            isSelected: _selectedSource == 0,
                            onTap: () => setState(() => _selectedSource = 0),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ImportCard(
                            num: '02',
                            title: 'Paper PDF',
                            subtitle: 'Full manuscript & figures',
                            isSelected: _selectedSource == 1,
                            onTap: () => setState(() => _selectedSource = 1),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ImportCard(
                            num: '03',
                            title: 'Research notes',
                            subtitle: 'Markdown, BibTeX, highlights',
                            isSelected: _selectedSource == 2,
                            onTap: () => setState(() => _selectedSource = 2),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ImportCard(
                            num: '04',
                            title: 'Voice memo',
                            subtitle: 'Dictated thoughts & questions',
                            isSelected: _selectedSource == 3,
                            onTap: () => setState(() => _selectedSource = 3),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Mode 0: Link input
              if (_selectedSource == 0) ...[
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C2028) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              hintText: 'Paste arXiv URL, DOI, or paper link…',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.canaryYellow,
                              foregroundColor: const Color(0xFF141416),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              unawaited(_pasteFromClipboard());
                            },
                            child: const Text(
                              'Paste',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_selectedSource == 1) ...[
                // Mode 1: PDF Selector
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C2028) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF7675), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPdfName ?? 'Select document',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Extracted with pgvector embeddings',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedPdfName = 'deep_attention_scaling.pdf (1.8 MB)';
                            });
                          },
                          child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_selectedSource == 2) ...[
                // Mode 2: Notes input
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C2028) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Type or paste your research notes, bullet points, or thoughts…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ] else if (_selectedSource == 3) ...[
                // Mode 3: Voice memo
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C2028) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isRecording ? 'Recording voice memo…' : 'Tap to start speaking',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _isRecording ? const Color(0xFFFF7675) : (isDark ? Colors.white : const Color(0xFF141416)),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isRecording ? '00:0$_recordedSeconds / 05:00' : 'Speak up to 5 min of research thoughts',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isRecording = !_isRecording;
                              if (_isRecording) _recordedSeconds = 6;
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording ? const Color(0xFFFF7675) : (isDark ? AppTheme.canaryYellow : const Color(0xFF141416)),
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                              color: _isRecording ? Colors.white : (isDark ? const Color(0xFF141416) : Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 6),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 180),
                child: Text(
                  'Athena extracts core theorems, methodologies, empirical metrics, and findings.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // NARRATION VOICE Header & Selector
              AnimatedEntrance(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'SYNTHESIS VOICE & STYLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              AnimatedEntrance(
                delay: const Duration(milliseconds: 220),
                child: Row(
                  children: [
                    Expanded(
                      child: _VoiceCard(
                        name: 'Mara',
                        desc: 'Executive · narrative',
                        isSelected: _selectedVoice == 'Mara',
                        onTap: () => setState(() => _selectedVoice = 'Mara'),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _VoiceCard(
                        name: 'Dae',
                        desc: 'Technical · rigorous',
                        isSelected: _selectedVoice == 'Dae',
                        onTap: () => setState(() => _selectedVoice = 'Dae'),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _VoiceCard(
                        name: 'Rio',
                        desc: 'Concise · rapid',
                        isSelected: _selectedVoice == 'Rio',
                        onTap: () => setState(() => _selectedVoice = 'Rio'),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // LENGTH Header & Pills
              AnimatedEntrance(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  'SYNTHESIS DEPTH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              AnimatedEntrance(
                delay: const Duration(milliseconds: 270),
                child: Row(
                  children: [
                    for (final len in ['Brief · 5m', 'Standard · 12m', 'Deep · 25m']) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedLength = len),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedLength == len
                                  ? (isDark ? const Color(0xFF2B2F3B) : const Color(0xFFFFFFFF))
                                  : (isDark ? const Color(0xFF181A22) : const Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedLength == len
                                    ? (isDark ? AppTheme.canaryYellow : const Color(0xFF141416))
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                len,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: _selectedLength == len ? FontWeight.w800 : FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF141416),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (len != 'Deep · 25m') const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _lengthStats,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$_requiredCredits ${_requiredCredits == 1 ? "CREDIT" : "CREDITS"}',
                      style: const TextStyle(
                        color: Color(0xFFFF7675),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Yellow Tip Box
              AnimatedEntrance(
                delay: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282516) : const Color(0xFFFFFDE6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.canaryYellow.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.canaryYellow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TIP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF141416),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Batch multiple papers to synthesize a comparative literature review episode with citations.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Yellow Generate Audio Button
              AnimatedEntrance(
                delay: const Duration(milliseconds: 350),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.canaryYellow,
                          foregroundColor: const Color(0xFF141416),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: _isGenerating ? null : _startGeneration,
                        child: _isGenerating
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF141416)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _generationStep,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              )
                            : const Text(
                                'Synthesize audio brief',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$credits generation credits remaining',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String take(int n) => length <= n ? this : '${substring(0, n)}…';
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({
    required this.num,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String num;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF242834) : Colors.white)
              : (isDark ? const Color(0xFF1A1D24) : const Color(0xFFF7F8FA)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.canaryYellow : const Color(0xFF141416))
                : (isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB)),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              num,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isSelected ? AppTheme.coralPink : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF141416),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.name,
    required this.desc,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String name;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF141416)
              : (isDark ? const Color(0xFF1A1D24) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF141416)
                : (isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              size: 20,
              color: isSelected ? AppTheme.canaryYellow : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF141416)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? const Color(0xFFD1D5DB) : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
