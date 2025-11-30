import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

/// 笔顺动画组件
/// 解析 KanjiVG SVG 数据，逐笔画播放动画
class StrokeOrderAnimator extends StatefulWidget {
  /// SVG 字符串（来自 kana_stroke_order 表）
  final String svgData;

  /// 组件尺寸
  final double size;

  /// 笔画颜色
  final Color strokeColor;

  /// 已完成笔画颜色
  final Color completedColor;

  /// 背景笔画颜色（预览）
  final Color? backgroundStrokeColor;

  /// 单笔画动画时长
  final Duration strokeDuration;

  /// 是否自动播放
  final bool autoPlay;

  /// 是否循环播放
  final bool loop;

  /// 动画完成回调
  final VoidCallback? onComplete;

  const StrokeOrderAnimator({
    super.key,
    required this.svgData,
    this.size = 200,
    this.strokeColor = Colors.black,
    this.completedColor = Colors.black,
    this.backgroundStrokeColor,
    this.strokeDuration = const Duration(milliseconds: 800),
    this.autoPlay = true,
    this.loop = false,
    this.onComplete,
  });

  @override
  State<StrokeOrderAnimator> createState() => StrokeOrderAnimatorState();
}

class StrokeOrderAnimatorState extends State<StrokeOrderAnimator>
    with TickerProviderStateMixin {
  List<Path> _paths = [];
  List<double> _pathLengths = [];
  int _currentStroke = 0;
  AnimationController? _controller;
  Animation<double>? _animation;
  bool _isPlaying = false;
  double _viewBoxWidth = 109;
  double _viewBoxHeight = 109;

  @override
  void initState() {
    super.initState();
    _parseSvg();
    if (widget.autoPlay && _paths.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => play());
    }
  }

  @override
  void didUpdateWidget(StrokeOrderAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.svgData != widget.svgData) {
      _controller?.dispose();
      _controller = null;
      _currentStroke = 0;
      _isPlaying = false;
      _parseSvg();
      if (widget.autoPlay && _paths.isNotEmpty) {
        play();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 解析 SVG 数据
  void _parseSvg() {
    _paths = [];
    _pathLengths = [];
    _viewBoxWidth = 109;
    _viewBoxHeight = 109;

    try {
      final document = XmlDocument.parse(widget.svgData);

      // 解析 viewBox
      final svgElement = document.findAllElements('svg').firstOrNull;
      if (svgElement != null) {
        final viewBox = svgElement.getAttribute('viewBox');
        if (viewBox != null) {
          final parts = viewBox.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            _viewBoxWidth = double.tryParse(parts[2]) ?? 109;
            _viewBoxHeight = double.tryParse(parts[3]) ?? 109;
          }
        }
      }

      final pathElements = document.findAllElements('path');

      for (final element in pathElements) {
        final d = element.getAttribute('d');
        if (d != null && d.isNotEmpty) {
          final path = _parseSvgPath(d);
          _paths.add(path);
          _pathLengths.add(_calculatePathLength(path));
        }
      }
    } catch (e) {
      debugPrint('SVG 解析错误: $e');
    }
  }

  /// 解析 SVG path d 属性
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
        // 计算反射控制点
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

  /// 分词 SVG path
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

  /// 计算路径长度
  double _calculatePathLength(Path path) {
    final metrics = path.computeMetrics();
    double length = 0;
    for (final metric in metrics) {
      length += metric.length;
    }
    return length;
  }

  /// 开始播放
  void play() {
    if (_paths.isEmpty) return;
    _currentStroke = 0;
    _isPlaying = true;
    _animateStroke();
  }

  /// 暂停
  void pause() {
    _controller?.stop();
    _isPlaying = false;
  }

  /// 继续
  void resume() {
    if (_controller != null && !_isPlaying) {
      _controller!.forward();
      _isPlaying = true;
    }
  }

  /// 重置
  void reset() {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    setState(() {
      _currentStroke = 0;
      _isPlaying = false;
    });
  }

  /// 播放单个笔画动画
  void _animateStroke() {
    if (_currentStroke >= _paths.length) {
      _isPlaying = false;
      widget.onComplete?.call();
      if (widget.loop) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            play();
          }
        });
      }
      return;
    }

    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: widget.strokeDuration,
    );

    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));

    _controller!.addListener(() {
      setState(() {});
    });

    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentStroke++;
        _animateStroke();
      }
    });

    _controller!.forward();
  }

  @override
  Widget build(BuildContext context) {
    // 根据 viewBox 宽高比计算实际显示尺寸
    final aspectRatio = _viewBoxWidth / _viewBoxHeight;
    final displayWidth = aspectRatio > 1
        ? widget.size
        : widget.size * aspectRatio;
    final displayHeight = aspectRatio > 1
        ? widget.size / aspectRatio
        : widget.size;

    return SizedBox(
      width: displayWidth,
      height: displayHeight,
      child: CustomPaint(
        painter: _StrokeOrderPainter(
          paths: _paths,
          pathLengths: _pathLengths,
          currentStroke: _currentStroke,
          progress: _animation?.value ?? 0,
          strokeColor: widget.strokeColor,
          completedColor: widget.completedColor,
          backgroundStrokeColor: widget.backgroundStrokeColor,
          viewBoxWidth: _viewBoxWidth,
          viewBoxHeight: _viewBoxHeight,
          displayWidth: displayWidth,
          displayHeight: displayHeight,
        ),
      ),
    );
  }
}

class _StrokeOrderPainter extends CustomPainter {
  final List<Path> paths;
  final List<double> pathLengths;
  final int currentStroke;
  final double progress;
  final Color strokeColor;
  final Color completedColor;
  final Color? backgroundStrokeColor;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double displayWidth;
  final double displayHeight;

  _StrokeOrderPainter({
    required this.paths,
    required this.pathLengths,
    required this.currentStroke,
    required this.progress,
    required this.strokeColor,
    required this.completedColor,
    this.backgroundStrokeColor,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.displayWidth,
    required this.displayHeight,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // 根据 viewBox 缩放到目标尺寸
    final scaleX = displayWidth / viewBoxWidth;
    final scaleY = displayHeight / viewBoxHeight;
    canvas.scale(scaleX, scaleY);

    final backgroundPaint = Paint()
      ..color = backgroundStrokeColor ?? Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final completedPaint = Paint()
      ..color = completedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final currentPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 绘制背景笔画（预览）
    if (backgroundStrokeColor != null) {
      for (final path in paths) {
        canvas.drawPath(path, backgroundPaint);
      }
    }

    // 绘制已完成的笔画
    for (int i = 0; i < currentStroke && i < paths.length; i++) {
      canvas.drawPath(paths[i], completedPaint);
    }

    // 绘制当前笔画（动画中）
    if (currentStroke < paths.length && progress > 0) {
      final path = paths[currentStroke];
      final animatedPath = _extractPath(path, progress);
      canvas.drawPath(animatedPath, currentPaint);
    }
  }

  /// 提取路径的一部分
  Path _extractPath(Path originalPath, double fraction) {
    final extractedPath = Path();
    final metrics = originalPath.computeMetrics();

    for (final metric in metrics) {
      final length = metric.length * fraction;
      final extracted = metric.extractPath(0, length);
      extractedPath.addPath(extracted, Offset.zero);
    }

    return extractedPath;
  }

  @override
  bool shouldRepaint(covariant _StrokeOrderPainter oldDelegate) {
    return oldDelegate.currentStroke != currentStroke ||
        oldDelegate.progress != progress;
  }
}
