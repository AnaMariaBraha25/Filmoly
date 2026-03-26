import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class WatchProgress {
  final String videoUrl;
  final String title;
  final double positionSeconds; // Posición actual en segundos
  final double durationSeconds; // Duración total
  final DateTime lastWatched;

  WatchProgress({
    required this.videoUrl,
    required this.title,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.lastWatched,
  });

  /// Progreso en porcentaje (0-100)
  double get progress {
    if (durationSeconds <= 0) return 0;
    return (positionSeconds / durationSeconds) * 100;
  }

  /// Tiempo restante en segundos
  double get remainingSeconds => durationSeconds - positionSeconds;

  /// Conversión a JSON para almacenamiento
  Map<String, dynamic> toJson() {
    return {
      'videoUrl': videoUrl,
      'title': title,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'lastWatched': lastWatched.toIso8601String(),
    };
  }

  /// Creación desde JSON
  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    return WatchProgress(
      videoUrl: json['videoUrl'] as String,
      title: json['title'] as String,
      positionSeconds: (json['positionSeconds'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num).toDouble(),
      lastWatched: DateTime.parse(json['lastWatched'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchProgress &&
          runtimeType == other.runtimeType &&
          videoUrl == other.videoUrl;

  @override
  int get hashCode => videoUrl.hashCode;
}

/// Manager para guardar y cargar el progreso de visualización
class WatchProgressManager {
  static const String _fileName = 'watch_progress.json';
  static File? _progressFile;

  /// Obtiene la ruta del archivo de progreso
  static Future<File> _getProgressFile() async {
    if (_progressFile != null) return _progressFile!;
    
    final dir = await getApplicationDocumentsDirectory();
    _progressFile = File('${dir.path}/$_fileName');
    return _progressFile!;
  }

  /// Carga todos los registros de progreso
  static Future<List<WatchProgress>> loadProgress() async {
    try {
      final file = await _getProgressFile();
      
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      final jsonData = jsonDecode(contents) as List<dynamic>;
      
      return jsonData
          .map((item) => WatchProgress.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Watch progress: Error cargando progreso: $e');
      return [];
    }
  }

  /// Guarda el progreso de un video
  static Future<void> saveProgress(WatchProgress progress) async {
    try {
      final allProgress = await loadProgress();
      
      // Remueve el video si ya existe (por URL)
      allProgress.removeWhere((p) => p.videoUrl == progress.videoUrl);
      
      // Agrega el nuevo progreso
      allProgress.add(progress);
      
      // Guarda todos en el archivo
      final file = await _getProgressFile();
      final jsonData = allProgress.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      debugPrint('Watch progress: Error guardando progreso: $e');
    }
  }

  /// Obtiene el progreso de un video específico
  static Future<WatchProgress?> getProgressForVideo(String videoUrl) async {
    try {
      final allProgress = await loadProgress();
      return allProgress.firstWhereOrNull((p) => p.videoUrl == videoUrl);
    } catch (e) {
      debugPrint('Watch progress: Error obteniendo progreso del video: $e');
      return null;
    }
  }

  /// Elimina el progreso de un video
  static Future<void> removeProgress(String videoUrl) async {
    try {
      final allProgress = await loadProgress();
      allProgress.removeWhere((p) => p.videoUrl == videoUrl);
      
      final file = await _getProgressFile();
      final jsonData = allProgress.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      debugPrint('Watch progress: Error removiendo progreso: $e');
    }
  }

  /// Obtiene solo las películas con progreso > 0% y < 95% (excluyendo las casi terminadas)
  static Future<List<WatchProgress>> getInProgressMovies() async {
    try {
      final allProgress = await loadProgress();
      final inProgress = allProgress
          .where((p) => p.progress > 0 && p.progress < 95)
          .toList();
      
      // Ordena por última visto (más reciente primero)
      inProgress.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      
      return inProgress;
    } catch (e) {
      debugPrint('Watch progress: Error obteniendo películas en progreso: $e');
      return [];
    }
  }

  /// Limpia el registro de progreso (nota: no restablece el archivo)
  /// Se usa principalmente para depuración
  static Future<void> clearAllProgress() async {
    try {
      final file = await _getProgressFile();
      await file.writeAsString(jsonEncode([]));
    } catch (e) {
      debugPrint('Watch progress: Error limpiando progreso: $e');
    }
  }
}

// Extensión auxiliar para no tener que importar List.firstWhereOrNull
extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
