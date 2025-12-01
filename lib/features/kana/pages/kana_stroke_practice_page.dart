import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

import '../../../core/widgets/stroke_order_animator.dart';
import '../../../data/models/kana_detail.dart';
import '../../../data/repositories/kana_repository_provider.dart';
import '../../../services/audio_service_provider.dart';
import '../state/kana_chart_state.dart';

const double _progressInfoHeight = 36;

/// 假名笔顺练习页面（全屏）
class KanaStrokePracticePage extends ConsumerStatefulWidget {
  final List<KanaLetterWithState> kanaLetters;
  final int initialIndex;
  final KanaDisplayMode displayMode;

  const KanaStrokePracticePage({
    super.key,
    required this.kanaLetters,
    required this.initialIndex,
    required this.displayMode,
  });

  @override
  ConsumerState<KanaStrokePracticePage> createState() =>
      _KanaStrokePracticePageState();
}

class _KanaStrokePracticePageState
    extends ConsumerState<KanaStrokePracticePage> {
  late int _currentIndex;
  String? _svgData;
  String? _audioFilename;
  bool _isLoading = true;
  bool _showFinalGlyph = false;
  bool _canPractice = false;
  StrokeGuideData? _currentGuide;

  final _animatorKey = GlobalKey<StrokeOrderAnimatorState>();
  final _traceKey = GlobalKey<_StrokeTraceCanvasState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadCurrentKana();
  }

  Future<void> _loadCurrentKana() async {
    setState(() {
      _isLoading = true;
      _showFinalGlyph = false;
      _canPractice = false;
      _currentGuide = null;
    });

    final kana = widget.kanaLetters[_currentIndex];
    final repository = ref.read(kanaRepositoryProvider);
    final strokeOrder = await repository.getKanaStrokeOrder(kana.letter.id);
    final kanaAudio = await repository.getKanaAudio(kana.letter.id);

    final svgData = widget.displayMode == KanaDisplayMode.hiragana
        ? strokeOrder?.hiraganaSvg
        : strokeOrder?.katakanaSvg;

    if (!mounted) return;
    setState(() {
      _svgData = svgData;
      _audioFilename = kanaAudio?.audioFilename;
      _isLoading = false;
      _canPractice = false;
      _currentGuide =
          svgData != null && svgData.isNotEmpty ? StrokeGuideData.fromSvg(svgData) : null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animatorKey.currentState?.reset();
      _animatorKey.currentState?.play();
      _traceKey.currentState?.resetProgress();
    });
  }

  KanaLetterWithState get _currentKana => widget.kanaLetters[_currentIndex];

  String _displayText(KanaLetterWithState kana) {
    return widget.displayMode == KanaDisplayMode.hiragana
        ? kana.letter.hiragana ?? ''
        : kana.letter.katakana ?? '';
  }

  void _playAudio() {
    if (_audioFilename == null || _audioFilename!.isEmpty) return;
    final audioService = ref.read(audioServiceProvider);
    audioService.playAudio('assets/audio/kana/${_audioFilename!}');
  }

  void _replayAnimation() {
    setState(() {
      _showFinalGlyph = false;
      _canPractice = false;
    });
    _animatorKey.currentState?.reset();
    _animatorKey.currentState?.play();
    _traceKey.currentState?.resetProgress();
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= widget.kanaLetters.length) return;
    _currentIndex = index;
    _loadCurrentKana();
  }

  void _goPrev() => _goToIndex(_currentIndex - 1);

  void _goNext() => _goToIndex(_currentIndex + 1);

  @override
  Widget build(BuildContext context) {
    final kana = _currentKana;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('${_displayText(kana)} 笔顺练习'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _svgData == null || _svgData!.isEmpty
                ? const Center(child: Text('暂无笔顺数据', style: TextStyle(color: Colors.grey)))
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _buildHeader(context, kana),
                        const SizedBox(height: 12),
                        _buildControls(context),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Center(
                            child: _buildPracticeArea(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBottomHint(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, KanaLetterWithState kana) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentIndex > 0 ? _goPrev : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayText(kana),
                  style: const TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  kana.letter.romaji ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                _currentIndex < widget.kanaLetters.length - 1 ? _goNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: _playAudio,
          icon: const Icon(Icons.volume_up),
          label: const Text('播放音频'),
        ),
        FilledButton.icon(
          onPressed: _replayAnimation,
          icon: const Icon(Icons.refresh),
          label: const Text('重新播放'),
        ),
      ],
    );
  }

  Widget _buildPracticeArea(BuildContext context) {
    final size = min(MediaQuery.of(context).size.width * 0.8, 360.0);
    final guide = _currentGuide;
    final painterSize =
        guide != null ? guide.displaySizeFor(size) : Size.square(size);
    final cardDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );

    if (!_canPractice) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: cardDecoration,
            child: SizedBox.fromSize(
              size: painterSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    color: Colors.white,
                  ),
                  StrokeOrderAnimator(
                    key: _animatorKey,
                    svgData: _svgData ?? '',
                    size: size,
                    strokeColor: Theme.of(context).primaryColor,
                    completedColor: Colors.black87,
                    backgroundStrokeColor: Colors.transparent,
                    strokeDuration: const Duration(milliseconds: 600),
                    autoPlay: true,
                    loop: false,
                    onComplete: () {
                      setState(() {
                        _showFinalGlyph = true;
                        _canPractice = true;
                      });
                    },
                  ),
                  if (guide != null)
                    AnimatedOpacity(
                      opacity: _showFinalGlyph ? 1 : 0,
                      duration: const Duration(milliseconds: 400),
                      child: CustomPaint(
                        size: painterSize,
                        painter: _StrokeGlyphPainter(
                          guide: guide,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _progressInfoHeight,
            child: Center(
              child: Text(
                guide != null
                    ? '正在播放笔顺动画...'
                    : '加载笔顺数据...',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ),
        ],
      );
    }

    return StrokeTraceCanvas(
      key: _traceKey,
      svgData: _svgData ?? '',
      size: size,
      enabled: _canPractice,
      backgroundBuilder: (canvasSize, guide) {
        return [
          AnimatedOpacity(
            opacity: _showFinalGlyph ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: SizedBox.fromSize(
              size: canvasSize,
              child: CustomPaint(
                size: canvasSize,
                painter: _StrokeGlyphPainter(
                  guide: guide,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ];
      },
      onAllCompleted: () {
        // 可以在此处添加其他完成后的反馈（如动画或音效）
      },
    );
  }

  Widget _buildBottomHint() {
    const double messageHeight = 48;
    return SizedBox(
      height: messageHeight,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _canPractice
                ? '按照提示轨迹描红，每一笔都要准确。'
                : '先观看完整书写动画，动画结束后开始描红练习。',
            key: ValueKey<bool>(_canPractice),
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),
      ),
    );
  }

}

/// 练习描红画布
class StrokeTraceCanvas extends StatefulWidget {
  final String svgData;
  final double size;
  final VoidCallback? onAllCompleted;
  final List<Widget> Function(Size painterSize, StrokeGuideData guide)?
      backgroundBuilder;
  final bool enabled;

  const StrokeTraceCanvas({
    super.key,
    required this.svgData,
    this.size = 280,
    this.onAllCompleted,
    this.backgroundBuilder,
    this.enabled = true,
  });

  @override
  _StrokeTraceCanvasState createState() => _StrokeTraceCanvasState();
}

class _StrokeTraceCanvasState extends State<StrokeTraceCanvas> {
  StrokeGuideData? _guide;
  int _currentStroke = 0;
  final List<Path> _completed = [];
  final List<Offset> _currentPoints = [];
  String? _feedback;
  bool _showRetry = false;
  bool _allDone = false;

  StrokeGuideData? get guide => _guide;

  @override
  void initState() {
    super.initState();
    _guide = StrokeGuideData.fromSvg(widget.svgData);
  }

  @override
  void didUpdateWidget(covariant StrokeTraceCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.svgData != widget.svgData) {
      _guide = StrokeGuideData.fromSvg(widget.svgData);
      resetProgress();
    }
  }

  void resetProgress() {
    setState(() {
      _currentStroke = 0;
      _completed.clear();
      _currentPoints.clear();
      _feedback = null;
      _showRetry = false;
      _allDone = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    if (guide == null || guide.paths.isEmpty) {
      return const Text('暂无笔画数据', style: TextStyle(color: Colors.grey));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = min(widget.size, constraints.maxWidth);
        final painterSize = guide.displaySizeFor(maxSide);
        final backgroundLayers =
            widget.backgroundBuilder?.call(painterSize, guide) ??
                const <Widget>[];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onPanStart: (details) => _onPanStart(details, painterSize),
              onPanUpdate: (details) => _onPanUpdate(details, painterSize),
              onPanEnd: (_) => _onPanEnd(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ...backgroundLayers,
                    CustomPaint(
                      size: painterSize,
                      painter: _StrokeTracePainter(
                        guide: guide,
                        currentStroke: _currentStroke,
                        completedPaths: _completed,
                        currentPoints: _currentPoints,
                        showRetry: _showRetry,
                      ),
                    ),
                    if (_feedback != null)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              _feedback!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _progressInfoHeight,
              child: Center(
                child: Text(
                  _allDone
                      ? '练习完成！'
                      : '当前第 ${_currentStroke + 1}/${guide.paths.length} 笔',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onPanStart(DragStartDetails details, Size painterSize) {
    if (_guide == null || _allDone || !widget.enabled) return;

    final point = _toSvg(details.localPosition, painterSize);
    final targetStart = _guide!.startPoints[_currentStroke];
    final distance = (point - targetStart).distance;

    if (distance > 10) {
      setState(() {
        _feedback = '从起笔点开始';
        _showRetry = true;
      });
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _feedback = null;
      _showRetry = false;
      _currentPoints
        ..clear()
        ..add(point);
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size painterSize) {
    if (_guide == null || _allDone || !widget.enabled) return;
    if (_currentPoints.isEmpty) return;

    final point = _toSvg(details.localPosition, painterSize);
    _currentPoints.add(point);

    final deviation =
        _guide!.distanceToPath(_guide!.paths[_currentStroke], point);
    if (deviation > 25 && !_showRetry) {
      setState(() {
        _feedback = '再试一次';
        _showRetry = true;
      });
      HapticFeedback.lightImpact();
    } else {
      setState(() {});
    }
  }

  void _onPanEnd() {
    if (_guide == null || _currentPoints.isEmpty || _allDone || !widget.enabled) {
      return;
    }

    final path = _guide!.paths[_currentStroke];
    double maxDeviation = 0;
    for (final point in _currentPoints) {
      maxDeviation = max(
        maxDeviation,
        _guide!.distanceToPath(path, point),
      );
    }

    if (maxDeviation > 25) {
      setState(() {
        _feedback = '再试一次';
        _showRetry = true;
        _currentPoints.clear();
      });
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _feedback = null;
      _showRetry = false;
      _completed.add(path);
      _currentPoints.clear();
      _currentStroke++;
      if (_currentStroke >= _guide!.paths.length) {
        _allDone = true;
        widget.onAllCompleted?.call();
      }
    });
  }

  Offset _toSvg(Offset local, Size painterSize) {
    final guide = _guide!;
    final scaleX = painterSize.width / guide.viewBoxWidth;
    final scaleY = painterSize.height / guide.viewBoxHeight;
    return Offset(local.dx / scaleX, local.dy / scaleY);
  }
}

/// 画描红及提示
class _StrokeTracePainter extends CustomPainter {
  final StrokeGuideData guide;
  final int currentStroke;
  final List<Path> completedPaths;
  final List<Offset> currentPoints;
  final bool showRetry;

  _StrokeTracePainter({
    required this.guide,
    required this.currentStroke,
    required this.completedPaths,
    required this.currentPoints,
    required this.showRetry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / guide.viewBoxWidth;
    final scaleY = size.height / guide.viewBoxHeight;
    canvas.scale(scaleX, scaleY);

    final templatePaint = Paint()
      ..color = const Color(0xFFC8C8C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final guidePaint = Paint()
      ..color = const Color(0x80337AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final completedPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final userPaint = Paint()
      ..color = const Color(0xFF337AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 模板轮廓
    for (final path in guide.paths) {
      canvas.drawPath(path, templatePaint);
    }

    // 已完成笔画
    for (final path in completedPaths) {
      canvas.drawPath(path, completedPaint);
    }

    // 当前目标笔画提示
    if (currentStroke < guide.paths.length) {
      canvas.drawPath(guide.paths[currentStroke], guidePaint);

      final start = guide.startPoints[currentStroke];
      final startPaint = Paint()
        ..color = showRetry ? Colors.red : Colors.grey
        ..style = PaintingStyle.fill;
      canvas.drawCircle(start, 3.5, startPaint);
    }

    // 用户当前绘制的路径
    if (currentPoints.isNotEmpty) {
      final path = Path()..moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (int i = 1; i < currentPoints.length; i++) {
        path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(path, userPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokeTracePainter oldDelegate) {
    return oldDelegate.currentStroke != currentStroke ||
        oldDelegate.completedPaths.length != completedPaths.length ||
        oldDelegate.currentPoints.length != currentPoints.length ||
        oldDelegate.showRetry != showRetry;
  }
}

/// 解析 SVG 并提供笔画数据
class StrokeGuideData {
  final List<Path> paths;
  final List<Offset> startPoints;
  final double viewBoxWidth;
  final double viewBoxHeight;

  StrokeGuideData({
    required this.paths,
    required this.startPoints,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
  });

  factory StrokeGuideData.fromSvg(String svgData) {
    final parser = _StrokePathParser(svgData);
    return StrokeGuideData(
      paths: parser.paths,
      startPoints: parser.startPoints,
      viewBoxWidth: parser.viewBoxWidth,
      viewBoxHeight: parser.viewBoxHeight,
    );
  }

  Size displaySizeFor(double maxSide) {
    final aspect = viewBoxWidth / viewBoxHeight;
    final width = aspect >= 1 ? maxSide : maxSide * aspect;
    final height = aspect >= 1 ? maxSide / aspect : maxSide;
    return Size(width, height);
  }

  double distanceToPath(Path path, Offset point) {
    double minDistance = double.infinity;
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      for (double d = 0; d <= length; d += max(2, length / 80)) {
        final pos = metric.getTangentForOffset(d)?.position;
        if (pos == null) continue;
        minDistance = min(minDistance, (pos - point).distance);
      }
    }
    return minDistance;
  }
}

/// 正确整字形态
class _StrokeGlyphPainter extends CustomPainter {
  final StrokeGuideData guide;
  final Color color;

  _StrokeGlyphPainter({required this.guide, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / guide.viewBoxWidth;
    final scaleY = size.height / guide.viewBoxHeight;
    canvas.scale(scaleX, scaleY);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final path in guide.paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokeGlyphPainter oldDelegate) {
    return oldDelegate.guide != guide || oldDelegate.color != color;
  }
}

/// SVG 路径解析器（简化版，复用 StrokeOrderAnimator 的逻辑）
class _StrokePathParser {
  final String svgData;
  final List<Path> paths = [];
  final List<Offset> startPoints = [];
  double viewBoxWidth = 109;
  double viewBoxHeight = 109;

  _StrokePathParser(this.svgData) {
    _parse();
  }

  void _parse() {
    try {
      final document = XmlDocument.parse(svgData);
      final svgElement = document.findAllElements('svg').firstOrNull;
      if (svgElement != null) {
        final viewBox = svgElement.getAttribute('viewBox');
        if (viewBox != null) {
          final parts = viewBox.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            viewBoxWidth = double.tryParse(parts[2]) ?? 109;
            viewBoxHeight = double.tryParse(parts[3]) ?? 109;
          }
        }
      }

      final pathElements = document.findAllElements('path');
      for (final element in pathElements) {
        final d = element.getAttribute('d');
        if (d == null || d.isEmpty) continue;
        final path = _parseSvgPath(d);
        paths.add(path);
        final startMetric = path.computeMetrics().firstOrNull;
        startPoints.add(
          startMetric?.getTangentForOffset(0)?.position ?? Offset.zero,
        );
      }
    } catch (_) {
      // 解析异常时保持空数据
    }
  }

  Path _parseSvgPath(String d) {
    final path = Path();
    final commands = _tokenizePath(d);

    double currentX = 0;
    double currentY = 0;
    double startX = 0;
    double startY = 0;
    String lastCommand = '';
    double lastControlX = 0;
    double lastControlY = 0;

    int i = 0;
    while (i < commands.length) {
      final cmd = commands[i];

      if (cmd == 'M' || cmd == 'm') {
        final x = double.parse(commands[++i]);
        final y = double.parse(commands[++i]);
        if (cmd == 'M') {
          currentX = x;
          currentY = y;
        } else {
          currentX += x;
          currentY += y;
        }
        startX = currentX;
        startY = currentY;
        path.moveTo(currentX, currentY);
        lastCommand = cmd;
      } else if (cmd == 'L' || cmd == 'l') {
        final x = double.parse(commands[++i]);
        final y = double.parse(commands[++i]);
        if (cmd == 'L') {
          currentX = x;
          currentY = y;
        } else {
          currentX += x;
          currentY += y;
        }
        path.lineTo(currentX, currentY);
        lastCommand = cmd;
      } else if (cmd == 'H' || cmd == 'h') {
        final x = double.parse(commands[++i]);
        currentX = cmd == 'H' ? x : currentX + x;
        path.lineTo(currentX, currentY);
        lastCommand = cmd;
      } else if (cmd == 'V' || cmd == 'v') {
        final y = double.parse(commands[++i]);
        currentY = cmd == 'V' ? y : currentY + y;
        path.lineTo(currentX, currentY);
        lastCommand = cmd;
      } else if (cmd == 'C' || cmd == 'c') {
        double x1 = double.parse(commands[++i]);
        double y1 = double.parse(commands[++i]);
        double x2 = double.parse(commands[++i]);
        double y2 = double.parse(commands[++i]);
        double x = double.parse(commands[++i]);
        double y = double.parse(commands[++i]);
        if (cmd == 'c') {
          x1 += currentX;
          y1 += currentY;
          x2 += currentX;
          y2 += currentY;
          x += currentX;
          y += currentY;
        }
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastControlX = x2;
        lastControlY = y2;
        currentX = x;
        currentY = y;
        lastCommand = cmd;
      } else if (cmd == 'S' || cmd == 's') {
        double x2 = double.parse(commands[++i]);
        double y2 = double.parse(commands[++i]);
        double x = double.parse(commands[++i]);
        double y = double.parse(commands[++i]);
        if (cmd == 's') {
          x2 += currentX;
          y2 += currentY;
          x += currentX;
          y += currentY;
        }
        double x1 = currentX;
        double y1 = currentY;
        if (lastCommand == 'C' ||
            lastCommand == 'c' ||
            lastCommand == 'S' ||
            lastCommand == 's') {
          x1 = 2 * currentX - lastControlX;
          y1 = 2 * currentY - lastControlY;
        }
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastControlX = x2;
        lastControlY = y2;
        currentX = x;
        currentY = y;
        lastCommand = cmd;
      } else if (cmd == 'Q' || cmd == 'q') {
        double x1 = double.parse(commands[++i]);
        double y1 = double.parse(commands[++i]);
        double x = double.parse(commands[++i]);
        double y = double.parse(commands[++i]);
        if (cmd == 'q') {
          x1 += currentX;
          y1 += currentY;
          x += currentX;
          y += currentY;
        }
        path.quadraticBezierTo(x1, y1, x, y);
        lastControlX = x1;
        lastControlY = y1;
        currentX = x;
        currentY = y;
        lastCommand = cmd;
      } else if (cmd == 'Z' || cmd == 'z') {
        path.close();
        currentX = startX;
        currentY = startY;
        lastCommand = cmd;
      }

      i++;
    }

    return path;
  }

  List<String> _tokenizePath(String d) {
    final tokens = <String>[];
    final regex = RegExp(r'([MmLlHhVvCcSsQqTtAaZz])|(-?\d+\.?\d*)');
    for (final match in regex.allMatches(d)) {
      final token = match.group(0);
      if (token != null && token.isNotEmpty) {
        tokens.add(token);
      }
    }
    return tokens;
  }
}
