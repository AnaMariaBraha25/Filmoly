import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
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

  /// Genera un hash único de la URL (para comparación tolerante)
  String get urlHash => _hashUrl(videoUrl);

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

/// Hash simple para normalizar URLs
String _hashUrl(String url) {
  // Normaliza los caracteres especiales
  final normalized = url
      .replaceAll('%20', ' ')
      .replaceAll('%2F', '/')
      .replaceAll('%3F', '?')
      .replaceAll('%3D', '=')
      .replaceAll('%26', '&')
      .replaceAll('%28', '(')
      .replaceAll('%29', ')')
      .replaceAll('%5B', '[')
      .replaceAll('%5D', ']');
  
  // Calcula un hash simple usando los códigos ASCII
  int hash = 0;
  for (int i = 0; i < normalized.length; i++) {
    hash = ((hash << 5) - hash) + normalized.codeUnitAt(i);
    hash = hash & hash; // Convierte a entero de 32 bits
  }
  
  return hash.toUnsigned(32).toRadixString(16);
}

/// Manager para guardar y cargar el progreso de visualización
class WatchProgressManager {
  static const String _fileName = 'watch_progress.json';

  /// Obtiene la ruta del archivo de progreso (sin caché para evitar problemas)
  static Future<File> _getProgressFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = path.join(dir.path, _fileName);
    return File(filePath);
  }

  /// Carga todos los registros de progreso
  static Future<List<WatchProgress>> loadProgress() async {
    try {
      final file = await _getProgressFile();
      
      if (!await file.exists()) {
        debugPrint('Watch progress: No existe archivo de progreso aún');
        return [];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        debugPrint('Watch progress: Archivo de progreso vacío');
        return [];
      }
      
      final jsonData = jsonDecode(contents) as List<dynamic>;
      
      final result = jsonData
          .map((item) => WatchProgress.fromJson(item as Map<String, dynamic>))
          .toList();
      
      debugPrint('Watch progress: ✓ Cargados ${result.length} videos de ${file.path}');
      for (var video in result) {
        debugPrint('Watch progress:   - ${video.title}: ${video.progress.toStringAsFixed(1)}% (${video.positionSeconds.toInt()}s/${video.durationSeconds.toInt()}s)');
      }
      return result;
    } catch (e, st) {
      debugPrint('Watch progress: ✗ Error cargando progreso: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Guarda el progreso de un video
  static Future<void> saveProgress(WatchProgress progress) async {
    try {
      final allProgress = await loadProgress();
      debugPrint('Watch progress: Guardando progreso para: ${progress.title}');
      debugPrint('Watch progress:   URL: ${progress.videoUrl}');
      debugPrint('Watch progress:   Hash: ${progress.urlHash}');
      debugPrint('Watch progress:   Posición: ${progress.positionSeconds.toInt()}s / ${progress.durationSeconds.toInt()}s (${progress.progress.toStringAsFixed(1)}%)');
      
      // Remueve el video si ya existe (por hash de URL)
      final existingIndex = allProgress.indexWhere((p) => p.urlHash == progress.urlHash);
      if (existingIndex >= 0) {
        debugPrint('Watch progress:   ↺ Reemplazando entrada existente');
        allProgress.removeAt(existingIndex);
      }
      
      // Agrega el nuevo progreso
      allProgress.add(progress);
      
      // Guarda todos en el archivo
      final file = await _getProgressFile();
      final jsonData = allProgress.map((p) => p.toJson()).toList();
      final jsonString = jsonEncode(jsonData);
      
      await file.create(recursive: true);
      await file.writeAsString(jsonString);
      
      debugPrint('Watch progress: ✓ Guardado exitosamente en: ${file.path}');
      debugPrint('Watch progress:   Total videos en archivo: ${allProgress.length}');
    } catch (e, st) {
      debugPrint('Watch progress: ✗ Error guardando progreso: $e');
      debugPrint('$st');
    }
  }

  /// Obtiene el progreso de un video específico
  static Future<WatchProgress?> getProgressForVideo(String videoUrl) async {
    try {
      final allProgress = await loadProgress();
      final targetHash = _hashUrl(videoUrl);
      
      debugPrint('Watch progress: ═════════════════════════════════════════');
      debugPrint('Watch progress: Buscando progreso para:');
      debugPrint('Watch progress:   URL: $videoUrl');
      debugPrint('Watch progress:   Hash: $targetHash');
      debugPrint('Watch progress: ');
      debugPrint('Watch progress: Videos en archivo (${allProgress.length}):');
      
      for (var i = 0; i < allProgress.length; i++) {
        final prog = allProgress[i];
        final match = prog.urlHash == targetHash;
        final mark = match ? '✓ COINCIDE' : '✗';
        debugPrint('Watch progress:   [$i] $mark');
        debugPrint('Watch progress:       Progreso: ${prog.progress.toStringAsFixed(1)}%');
        debugPrint('Watch progress:       Hash: ${prog.urlHash}');
        if (prog.videoUrl.length < 100) {
          debugPrint('Watch progress:       URL: ${prog.videoUrl}');
        } else {
          debugPrint('Watch progress:       URL: ${prog.videoUrl.substring(0, 50)}...');
        }
      }
      
      final found = allProgress.firstWhereOrNull((p) => p.urlHash == targetHash);
      
      debugPrint('Watch progress: ');
      if (found != null) {
        debugPrint('Watch progress: ✓ ENCONTRADO - ${found.progress.toStringAsFixed(1)}% (${found.positionSeconds.toInt()}s/${found.durationSeconds.toInt()}s)');
      } else {
        debugPrint('Watch progress: ✗ NO ENCONTRADO - Se esperaba encontrar la URL');
      }
      debugPrint('Watch progress: ═════════════════════════════════════════');
      
      return found;
    } catch (e, st) {
      debugPrint('Watch progress: ✗ Error obteniendo progreso del video: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Elimina el progreso de un video
  static Future<void> removeProgress(String videoUrl) async {
    try {
      final allProgress = await loadProgress();
      final targetHash = _hashUrl(videoUrl);
      allProgress.removeWhere((p) => p.urlHash == targetHash);
      
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
