import 'package:flutter/material.dart';

import '../domain/annotation.dart';

/// Presentation extension providing Flutter [Color] mappings for [AnnotationColor].
extension AnnotationColorDisplay on AnnotationColor {
  Color get color => Color(colorHex);
  Color get tint => Color(tintHex);
}
