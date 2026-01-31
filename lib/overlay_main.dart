import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
// Using standard material icons for stability
import 'package:google_fonts/google_fonts.dart';
import 'drawing_painter.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: const OverlayScreen(),
    ),
  );
}

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  DrawingTool _currentTool = DrawingTool.pen;
  final Color _currentColor = Colors.black;
  final double _currentWidth = 5.0;

  ui.Image? _bitmap;
  List<DrawingPoint> _currentPath = [];

  bool _isMinimized = false;
  bool _isVertical = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _updateBitmap(List<DrawingPoint> path) async {
    if (path.isEmpty) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = MediaQuery.of(context).size;

    if (_bitmap != null) {
      canvas.drawImage(_bitmap!, Offset.zero, Paint());
    }

    final paint = _getPaint(_currentTool, _currentColor, _currentWidth);
    final drawPath = Path();
    drawPath.moveTo(path.first.offset.dx, path.first.offset.dy);
    for (var i = 1; i < path.length; i++) {
      drawPath.lineTo(path[i].offset.dx, path[i].offset.dy);
    }
    canvas.drawPath(drawPath, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());

    setState(() {
      _bitmap = img;
    });
  }

  Paint _getPaint(DrawingTool tool, Color color, double width) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    switch (tool) {
      case DrawingTool.pen:
        paint.color = color;
        break;
      case DrawingTool.highlighter:
        paint.color = color.withOpacity(0.4);
        break;
      case DrawingTool.eraser:
        paint.blendMode = BlendMode.clear;
        break;
      case DrawingTool.lasso:
        paint.color = Colors.blue.withOpacity(0.3);
        paint.style = PaintingStyle.fill;
        break;
      case DrawingTool.laser:
        paint.color = Colors.red;
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        break;
    }
    return paint;
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentPath = [
        DrawingPoint(
          offset: details.localPosition,
          tool: _currentTool,
          color: _currentColor,
          width: _currentWidth,
        ),
      ];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(
        DrawingPoint(
          offset: details.localPosition,
          tool: _currentTool,
          color: _currentColor,
          width: _currentWidth,
        ),
      );
    });
  }

  Timer? _laserTimer;

  void _onPanEnd(DragEndDetails details) {
    if (_currentTool == DrawingTool.laser) {
      _laserTimer?.cancel();
      _laserTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _currentPath = [];
          });
        }
      });
    } else {
      _updateBitmap(_currentPath);
      setState(() {
        _currentPath = [];
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      _bitmap = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Drawing Canvas
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              painter: DrawingPainter(
                bitmap: _bitmap,
                currentPath: _currentPath,
                currentTool: _currentTool,
                currentColor: _currentColor,
                currentWidth: _currentWidth,
              ),
              size: Size.infinite,
            ),
          ),

          // Toolbar
          Positioned(left: 10, top: 100, child: _buildToolbar()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    if (_isMinimized) {
      return GestureDetector(
        onTap: () => setState(() => _isMinimized = false),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: const Icon(Icons.edit, color: Colors.blue),
        ),
      );
    }

    final children = [
      _toolbarAction(Icons.edit, DrawingTool.pen, "畫筆"),
      _toolbarAction(Icons.highlight, DrawingTool.highlighter, "螢光筆"),
      _toolbarAction(Icons.auto_fix_normal, DrawingTool.eraser, "橡皮擦"),
      _toolbarAction(Icons.crop_free, DrawingTool.lasso, "索套"),
      _toolbarAction(Icons.auto_fix_high, DrawingTool.laser, "雷射筆"),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Divider(height: 1),
      ),
      _iconButton(
        _isVertical ? Icons.view_headline : Icons.view_column,
        () => setState(() => _isVertical = !_isVertical),
      ),
      _iconButton(
        Icons.delete_forever,
        _clearCanvas,
        color: Colors.red.shade400,
      ),
      _iconButton(
        Icons.chevron_left,
        () => setState(() => _isMinimized = true),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: _isVertical
              ? Column(mainAxisSize: MainAxisSize.min, children: children)
              : Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onPressed, {Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? Colors.grey.shade700, size: 22),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _toolbarAction(IconData icon, DrawingTool tool, String tooltip) {
    final isSelected = _currentTool == tool;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade700,
        size: 24,
      ),
      onPressed: () => setState(() => _currentTool = tool),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? Colors.blue.withOpacity(0.1)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
