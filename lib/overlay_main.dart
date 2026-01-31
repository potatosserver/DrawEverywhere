import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'drawing_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _isDrawingMode = true;
  Offset _toolbarPosition = const Offset(10, 100);
  bool _isDragging = false;
  
  Size _screenSize = const Size(1080, 1920); // Default fallback

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        if (size.width > 0 && size.height > 0) {
          setState(() {
            _screenSize = size;
          });
        }
      }
    });
  }

  Future<void> _updateBitmap(List<DrawingPoint> path) async {
    if (path.isEmpty) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final width = _screenSize.width.toInt().clamp(1, 4096);
    final height = _screenSize.height.toInt().clamp(1, 4096);

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

    try {
      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);

      setState(() {
        _bitmap = img;
        _currentPath = []; // Clear current path ONLY when bitmap is ready
      });
    } catch (e) {
      debugPrint("Bitmap update failed: $e");
    }
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
    if (!_isDrawingMode) return;
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
    if (!_isDrawingMode) return;
    // Fast update for real-time and trigger repaint
    _currentPath.add(DrawingPoint(
      offset: details.localPosition,
      tool: _currentTool,
      color: _currentColor,
      width: _currentWidth,
    ));
    setState(() {});
  }

  Timer? _laserTimer;

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawingMode) return;
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
      // Removed immediate clear to prevent "jump"
    }
  }

  void _clearCanvas() {
    setState(() {
      _bitmap = null;
    });
  }

  Future<void> _toggleDrawingMode() async {
    final newMode = !_isDrawingMode;
    if (newMode) {
      await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, WindowSize.matchParent, false);
    } else {
      // Interaction mode: calculate height needed to show toolbar
      // Height should be at least (top position + toolbar height)
      // Since it's a Column/Row, we'll estimate the max height.
      // Vertical toolbar can be up to ~600px, Horizontal ~100px.
      final double neededHeight = _toolbarPosition.dy + (_isVertical ? 650 : 150);
      await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, neededHeight.toInt(), false); 
    }
    setState(() {
      _isDrawingMode = newMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Drawing Canvas
          if (_isDrawingMode)
            GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              behavior: HitTestBehavior.opaque,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: DrawingPainter(
                    bitmap: _bitmap,
                    currentPath: _currentPath,
                    currentTool: _currentTool,
                    currentColor: _currentColor,
                    currentWidth: _currentWidth,
                  ),
                  size: _screenSize, // Stabilize with fixed screen size
                ),
              ),
            ),
          
          if (!_isDrawingMode)
            IgnorePointer(
              child: CustomPaint(
                painter: DrawingPainter(
                  bitmap: _bitmap,
                  currentPath: [],
                  currentTool: _currentTool,
                  currentColor: _currentColor,
                  currentWidth: _currentWidth,
                ),
                size: _screenSize, // Stabilize with fixed screen size
              ),
            ),

          // Toolbar / Bubble
          Positioned(
            left: _toolbarPosition.dx,
            top: _toolbarPosition.dy,
            child: GestureDetector(
              onLongPressStart: (details) {
                setState(() => _isDragging = true);
              },
              onPanUpdate: (details) {
                if (_isDragging) {
                  setState(() {
                    _toolbarPosition += details.delta;
                  });
                }
              },
              onPanEnd: (details) {
                setState(() => _isDragging = false);
              },
              child: _buildToolbar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    if (_isMinimized) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () async {
              if (_isDrawingMode) {
                await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, WindowSize.matchParent, false);
              } else {
                final double neededHeight = _toolbarPosition.dy + (_isVertical ? 650 : 150);
                await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, neededHeight.toInt(), false);
              }
              setState(() => _isMinimized = false);
            },
            child: const Icon(Icons.visibility, color: Colors.blue, size: 32),
          ),
        ),
      );
    }

    final children = [
      _iconButton(
        _isMinimized ? Icons.visibility_off : Icons.visibility,
        () async {
          final newState = !_isMinimized;
          if (newState) {
            // When minimizing, we don't necessarily need to resize the window small,
            // but if we want to allow interaction behind, we should.
            // For "upward collapse", we just hide other buttons.
            if (!_isDrawingMode) {
                final double neededHeight = _toolbarPosition.dy + 100; // Just enough for eye button
                await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, neededHeight.toInt(), false);
            }
          } else {
            if (_isDrawingMode) {
              await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, WindowSize.matchParent, false);
            } else {
              final double neededHeight = _toolbarPosition.dy + (_isVertical ? 650 : 150);
              await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, neededHeight.toInt(), false);
            }
          }
          setState(() => _isMinimized = newState);
        },
        color: Colors.blue,
      ),
      if (!_isMinimized) ...[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Divider(height: 1),
        ),
        _toolbarAction(Icons.edit, DrawingTool.pen, "畫筆"),
        _toolbarAction(Icons.highlight, DrawingTool.highlighter, "螢光筆"),
        _toolbarAction(Icons.auto_fix_normal, DrawingTool.eraser, "橡皮擦"),
        _toolbarAction(Icons.crop_free, DrawingTool.lasso, "套索"),
        _toolbarAction(Icons.auto_fix_high, DrawingTool.laser, "雷射筆"),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Divider(height: 1),
        ),
        _iconButton(
          _isDrawingMode ? Icons.edit : Icons.touch_app,
          _toggleDrawingMode,
          color: _isDrawingMode ? Colors.blue : Colors.orange,
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
          Icons.close,
          () => FlutterOverlayWindow.closeOverlay(),
          color: Colors.red,
        ),
      ]
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.8)),
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
      icon: Icon(icon, color: color ?? Colors.grey.shade700, size: 28),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _toolbarAction(IconData icon, DrawingTool tool, String tooltip) {
    final isSelected = _currentTool == tool && _isDrawingMode;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade700,
        size: 28,
      ),
      onPressed: () {
        if (!_isDrawingMode) _toggleDrawingMode();
        setState(() => _currentTool = tool);
      },
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
