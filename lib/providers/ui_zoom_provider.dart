import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../core/database/app_database.dart';

class UiZoomNotifier extends Notifier<double> {
  static const List<double> zoomSteps = [0.90, 1.00, 1.15, 1.25, 1.35];

  static String labelFor(double scale) {
    final pct = (scale * 100).round();
    switch (pct) {
      case 90:
        return '90% (Compacto)';
      case 100:
        return '100% (Normal)';
      case 115:
        return '115% (Grande)';
      case 125:
        return '125% (Muy Grande)';
      case 135:
        return '135% (Extra Grande)';
      default:
        return '$pct%';
    }
  }

  @override
  double build() {
    _loadSavedZoom();
    return 1.00;
  }

  bool get canZoomIn => state < zoomSteps.last - 0.001;
  bool get canZoomOut => state > zoomSteps.first + 0.001;

  void zoomIn() {
    for (final step in zoomSteps) {
      if (step > state + 0.001) {
        setZoom(step);
        return;
      }
    }
  }

  void zoomOut() {
    for (final step in zoomSteps.reversed) {
      if (step < state - 0.001) {
        setZoom(step);
        return;
      }
    }
  }

  void resetZoom() {
    setZoom(1.00);
  }

  void setZoom(double newScale) {
    final clamped = newScale.clamp(zoomSteps.first, zoomSteps.last);
    if ((state - clamped).abs() < 0.001) return;
    state = clamped;
    _saveZoom(clamped);
  }

  Future<void> _loadSavedZoom() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final dir = await AppDatabase.getCasartDirectory();
      final file = File(p.join(dir.path, 'ui_preferences.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final saved = (data['textScale'] as num?)?.toDouble();
        if (saved != null && zoomSteps.any((s) => (s - saved).abs() < 0.01)) {
          final match = zoomSteps.firstWhere((s) => (s - saved).abs() < 0.01);
          state = match;
        }
      }
    } catch (_) {}
  }

  Future<void> _saveZoom(double scale) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final dir = await AppDatabase.getCasartDirectory();
      final file = File(p.join(dir.path, 'ui_preferences.json'));
      await file.writeAsString(jsonEncode({'textScale': scale}));
    } catch (_) {}
  }
}

final uiZoomProvider = NotifierProvider<UiZoomNotifier, double>(
  UiZoomNotifier.new,
);
