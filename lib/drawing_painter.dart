import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum DrawingTool { pen, highlighter, eraser, lasso, laser }

class DrawingPoint {
  final Offset offset;
  final DrawingTool tool;
  final Color color;
  final double width;

  DrawingPoint({
    required this.offset,
    required this.tool,
    required this.color,
    required this.width,
  });
}

class DrawingPainter extends CustomPainter {
  final ui.Image? bitmap;
  final List<DrawingPoint> currentPath;
  final DrawingTool currentTool;
  final Color currentColor;
  final double currentWidth;

  DrawingPainter({
    this.bitmap,
    required this.currentPath,
    required this.currentTool,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bitmap != null) {
      canvas.drawImage(bitmap!, Offset.zero, Paint());
    }

    if (currentPath.isNotEmpty) {
      final paint = _getPaint(currentTool, currentColor, currentWidth);

      if (currentTool == DrawingTool.laser) {
        // Laser might have different rendering if needed,
        // but for now just draw the path.
      }

      final path = Path();
      path.moveTo(currentPath.first.offset.dx, currentPath.first.offset.dy);
      for (var i = 1; i < currentPath.length; i++) {
        path.lineTo(currentPath[i].offset.dx, currentPath[i].offset.dy);
      }

      canvas.drawPath(path, paint);
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

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.bitmap != bitmap ||
        oldDelegate.currentPath != currentPath;
  }
}
