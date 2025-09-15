// Di file terpisah: message_tail_painter.dart
import 'package:flutter/material.dart';

class RightMessageTailPainter extends CustomPainter {
  final Color color;
  final double tailLength; // Parameter untuk mengatur panjang tail
  
  RightMessageTailPainter(this.color, {this.tailLength = 8});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(tailLength, size.height / 2); // Gunakan tailLength
    path.lineTo(0, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LeftMessageTailPainter extends CustomPainter {
  final Color color;
  final double tailLength; // Parameter untuk mengatur panjang tail
  
  LeftMessageTailPainter(this.color, {this.tailLength = 8});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    
    final path = Path();
    path.moveTo(size.width, size.height);
    path.lineTo(size.width - tailLength, size.height / 2); // Gunakan tailLength
    path.lineTo(size.width, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}