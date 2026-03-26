import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';
import 'watch_progress.dart';

class _ExternalOption {
  final String label;
  final Future<void> Function() onSelected;

  _ExternalOption({required this.label, required this.onSelected});
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.initialPosition,
  });

  final String videoUrl;
  final String title;
  final Duration? initialPosition;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  static bool _mediaKitInitialized = false;

  Player? _player;
  VideoController? _videoController;
  VideoPlayerController? _webController;

  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _fallbackOpened = false;
  bool _isDownloading = false;
  String? _downloadStatus;

  String? _errorMessage;
  
  // Para guardar progreso
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  DateTime _lastProgressSave = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  Future<void> _startPlayback() async {
    if (_isInitializing) return;
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _fallbackOpened = false;
    });

    if (kIsWeb) {
      try {
        await _initWebController();
        _isPlaying = true;
      } catch (e, st) {
        debugPrint('VideoScreen: Web player failed with error: $e');
        debugPrint('$st');
        _errorMessage = 'No se pudo reproducir en web: $e';
      }
    } else {
      // En otras plataformas, intentar MediaKit
      try {
        debugPrint('VideoScreen: trying MediaKit for ${widget.videoUrl}');
        await _initMediaKit();
        debugPrint('VideoScreen: MediaKit playback setup completed');
        _isPlaying = true;
      } catch (e, st) {
        debugPrint('VideoScreen: MediaKit failed with error: $e');
        debugPrint('$st');
        _errorMessage = 'No se pudo reproducir localmente con MediaKit: $e';
      }
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }



  Future<void> _initMediaKit() async {
    _ensureMediaKitInitialized();
    final uri = _resolveUri(widget.videoUrl);

    _player = Player();
    _videoController = VideoController(_player!);

    debugPrint('VideoScreen: opening media URI=$uri');

    await _player!.open(Media(uri.toString()));
    
    // Si hay una posición inicial, busca a ella después de abrir
    if (widget.initialPosition != null) {
      await _player!.seek(widget.initialPosition!);
      debugPrint('VideoScreen: seeked to initial position ${widget.initialPosition}');
    }
    
    await _player!.play();

    // Observa la posición actual
    _player!.stream.position.listen(
      (position) {
        setState(() {
          _currentPosition = position;
        });
        
        // Guarda progreso cada 5 segundos
        final now = DateTime.now();
        if (now.difference(_lastProgressSave).inSeconds >= 5) {
          _saveProgressToStorage();
          _lastProgressSave = now;
        }
      },
      onError: (error) {
        debugPrint('VideoScreen: position stream error: $error');
      },
    );

    // Observa la duración
    _player!.stream.duration.listen(
      (duration) {
        setState(() {
          _videoDuration = duration;
        });
      },
      onError: (error) {
        debugPrint('VideoScreen: duration stream error: $error');
      },
    );

    _player!.stream.playing.listen(
      (playing) {
        debugPrint('VideoScreen: playing state $playing');
      },
      onError: (error) {
        debugPrint('VideoScreen: playing stream error: $error');
      },
    );
  }

  void _ensureMediaKitInitialized() {
    if (kIsWeb || _mediaKitInitialized) return;
    MediaKit.ensureInitialized();
    _mediaKitInitialized = true;
  }

  bool _isWebSupportedVideoFormat(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) return false;
    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    const supported = ['mp4', 'webm', 'ogg', 'm4v', 'mov'];
    return supported.contains(extension);
  }

  Future<void> _initWebController() async {
    final source = widget.videoUrl;
    if (!source.startsWith('http://') && !source.startsWith('https://')) {
      throw Exception('En web solo se admiten URLs http/https');
    }

    if (!_isWebSupportedVideoFormat(source)) {
      debugPrint(
          'Web: formato no estándar para reproducción directa (${source.split('.').last}), se intenta de todas formas.');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Formato no estándar en web. Puede descargarse/abrirse en otro reproductor externo.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    _webController = VideoPlayerController.networkUrl(Uri.parse(source));
    await _webController!.initialize();
    await _webController!.play();
  }

  Uri _resolveUri(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Uri.parse(source);
    }
    final file = File(source);
    if (!file.existsSync()) {
      throw Exception('Archivo no encontrado: $source');
    }
    return Uri.file(source);
  }

  Future<void> _openFallbackExternal() async {
    if (_fallbackOpened) return;
    _fallbackOpened = true;

    final source = widget.videoUrl;
    debugPrint('VideoScreen: fallback external open for $source');
    await _openExternalWithPicker(source);
  }

  Future<void> _openExternalWithPicker(String source) async {
    if (kIsWeb) {
      // En web no hay "open with" real desde Flutter; abrimos el recurso en nueva pestaña.
      if (source.startsWith('http://') || source.startsWith('https://')) {
        html.window.open(source, '_blank');
      } else {
        final url = Uri.tryParse(source);
        if (url != null) {
          html.window.open(url.toString(), '_blank');
        }
      }
      return;
    }

    if (Platform.isWindows) {
      // Cargamos opciones "típicas" y dejamos que el usuario elija.
      final options = <_ExternalOption>[];

      String? vlcPath;
      const vlcCandidates = [
        'C:\\Program Files\\VideoLAN\\VLC\\vlc.exe',
        'C:\\Program Files (x86)\\VideoLAN\\VLC\\vlc.exe',
      ];
      for (final c in vlcCandidates) {
        if (File(c).existsSync()) {
          vlcPath = c;
          break;
        }
      }
      if (vlcPath != null) {
        options.add(
          _ExternalOption(
            label: 'Abrir con VLC',
            onSelected: () async {
              await Process.start(vlcPath!, [source]);
            },
          ),
        );
      }

      options.add(
        _ExternalOption(
          label: 'Abrir con la app predeterminada',
          onSelected: () async {
            final uri =
                source.startsWith('http://') || source.startsWith('https://')
                ? Uri.parse(source)
                : Uri.file(source);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      );

      if (source.isNotEmpty && !source.startsWith('http')) {
        options.add(
          _ExternalOption(
            label: 'Ver en explorador',
            onSelected: () async {
              await Process.start('explorer.exe', [source]);
            },
          ),
        );
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            title: const Text('Abrir con...'),
            backgroundColor: Colors.black87,
            titleTextStyle: const TextStyle(color: Colors.white),
            content: const Text(
              'Elige con qué reproductor abrir el vídeo.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              for (final opt in options)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await opt.onSelected();
                  },
                  child: Text(
                    opt.label,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          );
        },
      );

      if (mounted) {
        setState(() {
          _errorMessage = 'Abrriendo con la opción seleccionada...';
        });
      }
      return;
    }

    // Android / Linux / macOS: usamos chooser del sistema.
    final uri = (source.startsWith('http://') || source.startsWith('https://'))
        ? Uri.parse(source)
        : Uri.file(source);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _togglePlayPause() async {
    if (_webController != null) {
      final playing = _webController!.value.isPlaying;
      if (playing) {
        await _webController!.pause();
      } else {
        await _webController!.play();
      }
      if (mounted) {
        setState(() {
          _isPlaying = !playing;
        });
      }
    } else if (_player != null) {
      final playing = _player!.state.playing;
      if (playing) {
        await _player!.pause();
      } else {
        await _player!.play();
      }
      if (mounted) {
        setState(() {
          _isPlaying = !playing;
        });
      }
    }
  }

  Future<void> _restartFromZero() async {
    if (_webController != null) {
      await _webController!.seekTo(Duration.zero);
      await _webController!.play();
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
      return;
    }
    if (_player != null) {
      await _player!.seek(Duration.zero);
      await _player!.play();
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
      return;
    }

  }

  Future<void> _showAudioTracks() async {
    if (_player != null) {
      final tracks = _player!.state.tracks.audio;
      final current = _player!.state.track.audio;
      if (tracks.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay pistas de audio disponibles')),
        );
        return;
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.black87,
        builder: (context) {
          return ListView(
            children: tracks
                .map(
                  (track) => ListTile(
                    title: Text(
                      track.title ?? 'Audio ${track.id}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: current.id == track.id
                        ? const Icon(Icons.check, color: Colors.greenAccent)
                        : null,
                    onTap: () async {
                      await _player!.setAudioTrack(track);
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          );
        },
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay pistas de audio seleccionables aquí'),
        ),
      );
    }
  }

  Future<void> _showSubtitleTracks() async {
    if (_player != null) {
      final tracks = _player!.state.tracks.subtitle;
      final current = _player!.state.track.subtitle;
      if (tracks.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay subtítulos disponibles')),
        );
        return;
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.black87,
        builder: (context) {
          return ListView(
            children: tracks
                .map(
                  (track) => ListTile(
                    title: Text(
                      track.title ?? 'Subtítulo ${track.id}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: current.id == track.id
                        ? const Icon(Icons.check, color: Colors.greenAccent)
                        : null,
                    onTap: () async {
                      await _player!.setSubtitleTrack(track);
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          );
        },
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay subtítulos seleccionables aquí')),
      );
    }
  }

  Future<void> _openCast() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cast no disponible en web por ahora')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Buscando dispositivos...')));
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se encontraron dispositivos disponibles'),
      ),
    );
  }

  String _sanitizeFileName(String name) {
    // Evita caracteres inválidos en Windows.
    final sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (sanitized.isEmpty) return '${DateTime.now().millisecondsSinceEpoch}';
    // Truncamos para no romper rutas largas.
    return sanitized.length > 180 ? sanitized.substring(0, 180) : sanitized;
  }

  String _resolveLocalPath(String source) {
    if (source.startsWith('file://')) {
      try {
        return Uri.parse(source).toFilePath();
      } catch (_) {
        return source;
      }
    }
    return source;
  }

  String _fileNameFromUrlOrPath(String source) {
    // Si es URL remota
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final uri = Uri.tryParse(source);
      if (uri == null || uri.pathSegments.isEmpty) {
        return _sanitizeFileName(
          '${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
      }
      final last = uri.pathSegments.last.trim();
      final decoded = Uri.decodeComponent(last);
      return _sanitizeFileName(decoded);
    }

    // Si es archivo local. Convertimos file:// si está presente.
    final localPath = _resolveLocalPath(source);
    final file = File(localPath);
    return _sanitizeFileName(
      file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : '${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  Future<Directory> _resolveDownloadDirectory() async {
    // 1) Preferimos descargas del sistema
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;

    // 2) Windows fallback via APPDATA / Usuario
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final fallbackDownloads = Directory('$userProfile\\Downloads');
        if (await fallbackDownloads.exists()) {
          return fallbackDownloads;
        }
      }
    }

    // 3) Android siempre usa externo si existe
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) return external;
    }

    // 4) Último recurso, carpeta de la app
    return getApplicationDocumentsDirectory();
  }

  Future<bool> _ensureDownloadPermission() async {
    // En web no hay permisos de filesystem
    if (kIsWeb) return true;

    // En Android hay que pedir permisos especiales
    if (!Platform.isAndroid) return true;

    // En Android 13+ READ_MEDIA_VIDEO controla lectura, pero para escritura vamos a
    // intentar storage permission (en la práctica suele permitir escribir en descargas).
    final statusVideos = await Permission.videos.request();
    if (statusVideos.isGranted || statusVideos.isLimited) return true;

    final statusStorage = await Permission.storage.request();
    return statusStorage.isGranted || statusStorage.isLimited;
  }

  Future<void> _downloadCurrentVideo() async {
    final source = widget.videoUrl;
    if (_isDownloading) return;

    // Validar que sea descargable
    if (!kIsWeb &&
        !source.startsWith('http://') &&
        !source.startsWith('https://')) {
      final localPath = _resolveLocalPath(source);
      final f = File(localPath);
      if (!f.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archivo local no encontrado para descargar'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    } else if (kIsWeb &&
        !(source.startsWith('http://') || source.startsWith('https://'))) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('En web solo se pueden descargar URLs http/https'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (!await _ensureDownloadPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permisos denegados para descargar'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadStatus = 'Iniciando descarga...';
    });

    // Mostrar mensaje de inicio
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_downloadStatus!),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      final fileName = _fileNameFromUrlOrPath(source);

      if (kIsWeb) {
        // En web, usar el método más simple: abrir con download attribute
        await _downloadWebFile(source, fileName);
      } else {
        // En Desktop (Windows, macOS, Linux)
        await _downloadDesktopFile(source, fileName);
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error al descargar: $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = null;
        });
      }
    }
  }

  Future<void> _downloadWebFile(String url, String fileName) async {
    try {
      debugPrint('Web download: attempting direct download for $fileName');

      if (mounted) {
        setState(() {
          _downloadStatus = 'Descargando $fileName...';
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_downloadStatus!),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Método directo: abrir con download attribute
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName);
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      // Mantener el estado de descarga por más tiempo para que el usuario vea el icono
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _downloadStatus = '✓ Descarga iniciada: $fileName';
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_downloadStatus!),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      debugPrint('Web direct download failed: $e, trying fallback');

      if (mounted) {
        setState(() {
          _downloadStatus = 'Reintentando descarga...';
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_downloadStatus!),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Fallback: abrir en nueva pestaña
      try {
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('target', '_blank');
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();

        // Mantener estado
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          setState(() {
            _downloadStatus = '⚠ Abierto en nueva pestaña: $fileName';
          });
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_downloadStatus!),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (fallbackError) {
        debugPrint('Web fallback also failed: $fallbackError');
        if (mounted) {
          setState(() {
            _downloadStatus = '✗ Error: máximo 2 intentos fallidos';
          });
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✗ Error: máximo 2 intentos fallidos'),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.red[700],
            ),
          );
        }
        rethrow;
      }
    }
  }

  Future<void> _downloadDesktopFile(String source, String fileName) async {
    final dir = await _resolveDownloadDirectory();
    await dir.create(recursive: true);
    final savePath = '${dir.path}${Platform.pathSeparator}$fileName';

    debugPrint('Desktop download to: $savePath');

    if (mounted) {
      setState(() {
        _downloadStatus = 'Descargando a: ${dir.path}';
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_downloadStatus!),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      if (source.startsWith('http://') || source.startsWith('https://')) {
        // Descarga HTTP/HTTPS usando Dio
        final dio = Dio();
        await dio.download(
          source,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1 && mounted) {
              final progress = received / total;
              setState(() {
                _downloadStatus = 'Descargando: ${(progress * 100).toStringAsFixed(0)}%';
              });
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_downloadStatus!),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress),
                    ],
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
        );
      } else {
        // Copia local
        if (mounted) {
          setState(() {
            _downloadStatus = 'Copiando archivo local...';
          });
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_downloadStatus!),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        final localPath = _resolveLocalPath(source);
        await File(localPath).copy(savePath);
      }

      debugPrint('Download completed: $savePath');

      if (mounted) {
        setState(() {
          _downloadStatus = '✓ Descarga completada';
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✓ Descarga completada:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  savePath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      debugPrint('Desktop download error: $e');

      // Limpiar archivo incompleto
      try {
        final incompleteFile = File(savePath);
        if (await incompleteFile.exists()) {
          await incompleteFile.delete();
          debugPrint('Removed incomplete file: $savePath');
        }
      } catch (cleanupError) {
        debugPrint('Cleanup error: $cleanupError');
      }

      rethrow;
    }
  }

  Widget _buildPlayerArea() {
    if (_webController != null && _webController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _webController!.value.aspectRatio == 0
            ? 16 / 9
            : _webController!.value.aspectRatio,
        child: VideoPlayer(_webController!),
      );
    }
    if (_videoController != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Video(controller: _videoController!),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _saveProgressToStorage() async {
    // Solo guarda si hay una duración válida y el progreso no es trivial
    if (_videoDuration.inSeconds <= 0) return;
    
    final progress = WatchProgress(
      videoUrl: widget.videoUrl,
      title: widget.title,
      positionSeconds: _currentPosition.inSeconds.toDouble(),
      durationSeconds: _videoDuration.inSeconds.toDouble(),
      lastWatched: DateTime.now(),
    );
    
    await WatchProgressManager.saveProgress(progress);
    debugPrint('VideoScreen: progreso guardado - ${progress.progress.toStringAsFixed(1)}%');
  }

  @override
  void dispose() {
    // Guarda el progreso antes de salir
    _saveProgressToStorage();

    _webController?.dispose();

    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Cast',
            onPressed: _openCast,
            icon: const Icon(Icons.cast, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Descargar',
            onPressed: _isDownloading ? null : _downloadCurrentVideo,
            icon: Icon(
              _isDownloading ? Icons.downloading : Icons.download,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isInitializing) ...[
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 14),
                            Text(
                              'Inicializando reproductor...',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_videoController != null ||
                        _webController != null) ...[
                      _buildPlayerArea(),
                      const SizedBox(height: 12),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            IconButton(
                              icon: const Icon(Icons.replay, color: Colors.white),
                              onPressed: _restartFromZero,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.audiotrack,
                                color: Colors.white,
                              ),
                              onPressed: _showAudioTracks,
                              tooltip: 'Audio',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.subtitles,
                                color: Colors.white,
                              ),
                              onPressed: _showSubtitleTracks,
                              tooltip: 'Subtítulos',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: _openFallbackExternal,
                          icon: const Icon(
                            Icons.open_in_new,
                            color: Colors.white70,
                          ),
                          label: const Text(
                            'Abrir en reproductor externo',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ] else ...[
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage ??
                                  'No se puede reproducir el vídeo en esta plataforma',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _openFallbackExternal,
                              child: const Text('Abrir con reproductor externo'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
