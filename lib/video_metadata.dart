import 'dart:io';
import 'dart:convert';

class VideoMetadata {
  final String resolution;
  final String bitrate;
  final String aspectRatio;
  final List<String> audioLanguages;
  final List<String> audioCodecs;
  final List<String> subtitles;
  final double sizeMB;
  final String quality;
  final double duration; // en segundos
  final String videoCodec;
  final int fps;
  final String frameRate;

  VideoMetadata({
    required this.resolution,
    required this.bitrate,
    required this.aspectRatio,
    required this.audioLanguages,
    required this.audioCodecs,
    required this.subtitles,
    required this.sizeMB,
    required this.quality,
    required this.duration,
    required this.videoCodec,
    required this.fps,
    required this.frameRate,
  });

  @override
  String toString() {
    return '''
=== METADATOS DEL VIDEO ===
Resolución: $resolution
Calidad: $quality
Bitrate: $bitrate
Aspect Ratio: $aspectRatio
FPS: $frameRate ($fps)
Codec Vídeo: $videoCodec
Duración: ${duration.toStringAsFixed(2)} segundos
Tamaño: ${sizeMB.toStringAsFixed(2)} MB
---
Audio:
  - Idiomas: ${audioLanguages.isEmpty ? 'desconocido' : audioLanguages.join(', ')}
  - Codecs: ${audioCodecs.isEmpty ? 'desconocido' : audioCodecs.join(', ')}
Subtítulos: ${subtitles.isEmpty ? 'ninguno' : subtitles.join(', ')}
    ''';
  }
}

Future<VideoMetadata> getVideoMetadata(String path) async {
  final file = File(path);
  final sizeMB = await file.length() / (1024 * 1024);

  // Valores por defecto
  String resolution = 'desconocida';
  String bitrate = 'desconocido';
  String aspectRatio = '16:9';
  List<String> audioLanguages = ['desconocido'];
  List<String> audioCodecs = [];
  List<String> subtitles = [];
  double duration = 0;
  String videoCodec = 'desconocido';
  int fps = 0;
  String frameRate = 'desconocido';
  String quality = 'desconocida';

  try {
    // Intentar con FFprobe primero
    final success = await _extractWithFFprobe(
      path,
      (r, b, ar, al, ac, d, vc, f, fr, s) {
        resolution = r;
        bitrate = b;
        aspectRatio = ar;
        audioLanguages = al;
        audioCodecs = ac;
        duration = d;
        videoCodec = vc;
        fps = f;
        frameRate = fr;
        subtitles = s;
      },
    );

    // Si FFprobe no funciona, usar MediaKit
    if (!success) {
      await _extractWithMediaKit(
        path,
        (d) {
          duration = d;
        },
      );
      
      // Fallback basado en nombre de archivo
      _extractFromFileName(
        path,
        (r, b, ar, al, ac, vc, f, fr, s) {
          if (resolution == 'desconocida') resolution = r;
          if (audioLanguages.first == 'desconocido') audioLanguages = al;
          if (videoCodec == 'desconocido') videoCodec = vc;
        },
      );
    }

    // Determinar calidad
    quality = _determineQuality(resolution);

  } catch (e) {
    print('Error general extrayendo metadatos: $e');
    // Mantener valores por defecto
  }

  return VideoMetadata(
    resolution: resolution,
    bitrate: bitrate,
    aspectRatio: aspectRatio,
    audioLanguages: audioLanguages.isEmpty ? ['desconocido'] : audioLanguages,
    audioCodecs: audioCodecs,
    subtitles: subtitles,
    sizeMB: sizeMB,
    quality: quality,
    duration: duration,
    videoCodec: videoCodec,
    fps: fps,
    frameRate: frameRate,
  );
}

Future<bool> _extractWithFFprobe(
  String path,
  Function(String, String, String, List<String>, List<String>, double, String, int, String, List<String>) onSuccess,
) async {
  try {
    // Para URLs web, usar directamente ffprobe
    // Para archivos locales, validar que existan
    if (!path.startsWith('http://') && !path.startsWith('https://')) {
      final file = File(path);
      if (!file.existsSync()) {
        print('Archivo no encontrado: $path');
        return false;
      }
    }

    // PASO 1: Buscar ffprobe.exe en el sistema
    String? ffprobePath = await _findFFprobe();
    
    if (ffprobePath == null) {
      print('FFprobe no encontrado en el sistema. Usando fallback.');
      return false;
    }

    print('Usando FFprobe encontrado en: $ffprobePath');

    // PASO 2: Ejecutar ffprobe con la ruta encontrada
    final result = await Process.run(
      ffprobePath,
      [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        '-i', path
      ],
      runInShell: false,
    );

    print('FFprobe return code: ${result.exitCode}');
    
    if (result.stderr.isNotEmpty) {
      final stderr = result.stderr.toString();
      print('FFprobe stderr: "$stderr"');
    }

    if (result.stdout.isNotEmpty) {
      print('FFprobe stdout length: ${result.stdout.length}');
      final stdout = result.stdout.toString();
      return _parseFFprobeJSON(stdout, onSuccess);
    } else {
      print('FFprobe no produjo salida');
      return false;
    }
  } catch (e) {
    print('FFprobe process error: $e');
    return false;
  }
}

/// Busca ffprobe.exe en el sistema
Future<String?> _findFFprobe() async {
  try {
    print('Buscando ffprobe en el sistema...');
    
    // Primero intentar buscar en ubicaciones comunes
    final List<String> commonPaths = [
      // Ubicaciones estándar
      'C:\\ffmpeg\\bin\\ffprobe.exe',
      'C:\\Program Files\\ffmpeg\\bin\\ffprobe.exe',
      'C:\\Program Files (x86)\\ffmpeg\\bin\\ffprobe.exe',
      'C:\\tools\\ffmpeg\\bin\\ffprobe.exe',
      'C:\\opt\\ffmpeg\\bin\\ffprobe.exe',
      // Chocolatey
      'C:\\ProgramData\\chocolatey\\lib\\ffmpeg\\tools\\bin\\ffprobe.exe',
      'C:\\ProgramData\\chocolatey\\bin\\ffprobe.exe',
      // WinGet (IMPORTANTE)
      'C:\\Users\\Ana\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffprobe.exe',
      'C:\\Users\\Ana\\AppData\\Local\\Programs\\ffmpeg\\bin\\ffprobe.exe',
      // scoop
      'C:\\Users\\Ana\\scoop\\apps\\ffmpeg\\current\\bin\\ffprobe.exe',
    ];
    
    // Agregar USERPROFILE si está disponible
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      commonPaths.addAll([
        '$userProfile\\ffmpeg\\bin\\ffprobe.exe',
        '$userProfile\\Downloads\\ffmpeg\\bin\\ffprobe.exe',
        '$userProfile\\AppData\\Local\\ffmpeg\\bin\\ffprobe.exe',
        '$userProfile\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffprobe.exe',
        '$userProfile\\AppData\\Local\\Programs\\ffmpeg\\bin\\ffprobe.exe',
        '$userProfile\\scoop\\apps\\ffmpeg\\current\\bin\\ffprobe.exe',
      ]);
    }

    // Agregar ProgramFiles/ProgramData si están disponibles
    final programFiles = Platform.environment['ProgramFiles'];
    if (programFiles != null && programFiles.isNotEmpty) {
      commonPaths.addAll([
        '$programFiles\\ffmpeg\\bin\\ffprobe.exe',
        '$programFiles (x86)\\ffmpeg\\bin\\ffprobe.exe',
      ]);
    }

    final programData = Platform.environment['ProgramData'];
    if (programData != null && programData.isNotEmpty) {
      commonPaths.add('$programData\\ffmpeg\\bin\\ffprobe.exe');
    }
    
    print('Buscando en ${commonPaths.length} ubicaciones...');
    
    // Buscar en ubicaciones comunes
    for (final probePath in commonPaths) {
      if (probePath.isNotEmpty) {
        try {
          if (File(probePath).existsSync()) {
            print('✓ FFprobe encontrado en: $probePath');
            return probePath;
          }
        } catch (e) {
          // Ignorar errores de acceso a archivo
        }
      }
    }

    print('No encontrado en ubicaciones comunes, intentando cmd where...');
    
    // Si no está en ubicaciones comunes, usar cmd.exe para ejecutar where
    try {
      final result = await Process.run(
        'cmd.exe',
        ['/c', 'where ffprobe.exe'],
        runInShell: false,
      );
      
      if (result.stdout.isNotEmpty && result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && trimmed.endsWith('.exe')) {
            print('✓ FFprobe encontrado con cmd where: $trimmed');
            if (File(trimmed).existsSync()) {
              return trimmed;
            }
          }
        }
      }
    } catch (e) {
      print('Error con cmd where: $e');
    }

    print('FFprobe no encontrado en el sistema');
    return null;
  } catch (e) {
    print('Error buscando FFprobe: $e');
    return null;
  }
}

bool _parseFFprobeJSON(
  String jsonString,
  Function(String, String, String, List<String>, List<String>, double, String, int, String, List<String>) onSuccess,
) {
  try {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    
    // Extraer información de formato
    String resolution = 'desconocida';
    String bitrate = 'desconocido';
    String aspectRatio = '16:9';
    List<String> audioLanguages = [];
    List<String> audioCodecs = [];
    double duration = 0;
    String videoCodec = 'desconocido';
    int fps = 0;
    String frameRate = 'desconocido';
    List<String> subtitles = [];

    // Duración desde format
    if (data['format'] is Map) {
      final format = data['format'] as Map<String, dynamic>;
      
      if (format['duration'] != null) {
        duration = double.tryParse(format['duration'].toString()) ?? 0;
      }
      
      if (format['bit_rate'] != null) {
        final br = int.tryParse(format['bit_rate'].toString()) ?? 0;
        if (br > 0) {
          bitrate = '${(br / 1000).toStringAsFixed(0)} kbps';
        }
      }
    }

    // Procesar streams
    if (data['streams'] is List) {
      final streams = data['streams'] as List;
      
      for (final streamRaw in streams) {
        final stream = streamRaw as Map<String, dynamic>;
        final codecType = stream['codec_type'] as String?;

        if (codecType == 'video') {
          // Resolución
          final width = stream['width'] as int?;
          final height = stream['height'] as int?;
          if (width != null && height != null && width > 0 && height > 0) {
            resolution = '${width}x$height';
          }

          // FPS
          if (stream['r_frame_rate'] is String) {
            frameRate = stream['r_frame_rate'] as String;
            final parts = frameRate.split('/');
            if (parts.length == 2) {
              final num = int.tryParse(parts[0]) ?? 0;
              final den = int.tryParse(parts[1]) ?? 1;
              if (den > 0) {
                fps = (num / den).round();
              }
            }
          }

          // Aspect Ratio
          if (stream['display_aspect_ratio'] is String && (stream['display_aspect_ratio'] as String).isNotEmpty) {
            aspectRatio = stream['display_aspect_ratio'] as String;
          }

          // Codec
          if (stream['codec_name'] is String) {
            videoCodec = stream['codec_name'] as String;
          }
        } else if (codecType == 'audio') {
          // Codec de audio
          if (stream['codec_name'] is String) {
            final codec = stream['codec_name'] as String;
            if (!audioCodecs.contains(codec) && codec.isNotEmpty) {
              audioCodecs.add(codec);
            }
          }

          // Idioma
          if (stream['tags'] is Map) {
            final tags = stream['tags'] as Map<String, dynamic>;
            if (tags['language'] is String) {
              final lang = tags['language'] as String;
              if (!audioLanguages.contains(lang) && lang.isNotEmpty) {
                audioLanguages.add(lang);
              }
            }
          }
        } else if (codecType == 'subtitle') {
          if (!subtitles.contains('sí')) {
            subtitles.add('sí');
          }
        }
      }
    }

    // Validación de datos
    if (audioLanguages.isEmpty) {
      audioLanguages.add('desconocido');
    }
    if (resolution == 'desconocida' || resolution.isEmpty) {
      return false;
    }

    onSuccess(resolution, bitrate, aspectRatio, audioLanguages, audioCodecs, duration, videoCodec, fps, frameRate, subtitles);
    return true;
  } catch (e) {
    print('Error parsing JSON: $e');
    return false;
  }
}

Future<void> _extractWithMediaKit(
  String path,
  Function(double) onDuration,
) async {
  try {
    // MediaKit puede ayudar con duración si es necesario
    // Por ahora simplemente no hacer nada, ya que ffprobe debería manejarlo
    onDuration(0);
  } catch (e) {
    print('MediaKit helper error: $e');
  }
}

void _extractFromFileName(
  String path,
  Function(String, String, String, List<String>, List<String>, String, int, String, List<String>) onSuccess,
) {
  final fileName = path.toLowerCase();

  String resolution = 'desconocida';
  String bitrate = 'desconocido';
  String aspectRatio = '16:9';
  List<String> audioLanguages = [];
  List<String> audioCodecs = [];
  String videoCodec = 'desconocido';
  int fps = 0;
  String frameRate = 'desconocido';
  List<String> subtitles = [];

  // Detectar resolución
  if (fileName.contains('2160') || fileName.contains('4k')) {
    resolution = '3840x2160';
  } else if (fileName.contains('1080')) {
    resolution = '1920x1080';
  } else if (fileName.contains('720')) {
    resolution = '1280x720';
  } else if (fileName.contains('480')) {
    resolution = '854x480';
  }

  // Detectar idiomas
  if (fileName.contains('spanish') || fileName.contains('spa') || fileName.contains('español')) {
    audioLanguages.add('es');
  }
  if (fileName.contains('english') || fileName.contains('eng')) {
    audioLanguages.add('en');
  }
  if (fileName.contains('french') || fileName.contains('fra')) {
    audioLanguages.add('fr');
  }
  if (fileName.contains('german') || fileName.contains('deu')) {
    audioLanguages.add('de');
  }

  // Detectar codecs
  if (fileName.contains('h.264') || fileName.contains('h264') || fileName.contains('avc')) {
    videoCodec = 'h264';
  } else if (fileName.contains('h.265') || fileName.contains('h265') || fileName.contains('hevc')) {
    videoCodec = 'h265';
  }

  if (fileName.contains('aac')) {
    audioCodecs.add('aac');
  } else if (fileName.contains('mp3')) {
    audioCodecs.add('mp3');
  }

  // Detectar subtítulos
  if (fileName.contains('sub')) {
    subtitles.add('sí');
  }

  onSuccess(resolution, bitrate, aspectRatio, audioLanguages, audioCodecs, videoCodec, fps, frameRate, subtitles);
}

String _determineQuality(String resolution) {
  if (resolution.contains('3840') || resolution.contains('4K') || resolution.contains('4k')) {
    return '4K';
  } else if (resolution.contains('2160')) {
    return '2160p';
  } else if (resolution.contains('1920')) {
    return '1080p';
  } else if (resolution.contains('1280') || resolution.contains('720')) {
    return '720p';
  } else if (resolution.contains('854') || resolution.contains('480')) {
    return '480p';
  } else if (resolution.contains('360')) {
    return '360p';
  }
  return 'desconocida';
}