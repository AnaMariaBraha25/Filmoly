import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter_cast_video/flutter_cast_video.dart';
import 'package:video_player/video_player.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.videoUrl, required this.title});

  final String videoUrl;
  final String title;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VlcPlayerController? _controller;
  bool _isVlcSupported = false;
  bool _isCastSupported = false;
  bool _isVideoPlayerSupported = false;

  // Controller provisto por `ChromeCastButton` para poder cargar el media
  // en el dispositivo de Chromecast/AirPlay.
  ChromeCastController? _castController;

  Duration? _lastPosition;

  // Listas de pistas
  Map<int, String> _audioTracks = const {};
  Map<int, String> _subtitles = const {};
  bool _tracksLoading = false;
  bool _tracksLoadedOnce = false;

  VideoPlayerController? _videoPlayerController;
  bool _isVideoPlayerInitialized = false;
  String? _videoPlayerError;

  @override
  void initState() {
    super.initState();

    // Comprobamos si VLC se puede usar en esta plataforma
    _isVlcSupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    // Comprobamos si Cast se puede usar en esta plataforma
    _isCastSupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    // Comprobamos si podemos reproducir en web/Windows con `video_player`.
    _isVideoPlayerSupported = kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

    if (_isVlcSupported) {
      _controller = VlcPlayerController.network(
        widget.videoUrl,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );

      // Cargamos pistas con reintentos, porque algunos streams (MKV/AVI)
      // tardan más en exponer tracks.
      _loadTracksWithRetry();
    } else if (_isVideoPlayerSupported) {
      // En web/Windows no usamos VLC (no hay plugin VLC para esas plataformas
      // en tu versión actual). Reproducimos MP4/streams con `video_player`.
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _initVideoPlayer();
    }
  }

  Future<void> _initVideoPlayer() async {
    try {
      await _videoPlayerController!.initialize();
      if (!mounted) return;
      setState(() {
        _isVideoPlayerInitialized = true;
        _videoPlayerError = null;
      });
      // En web/desktop puede haber limitaciones de autoplay, pero al menos se renderiza.
      await _videoPlayerController!.play();
    } catch (e, st) {
      debugPrint('video_player initialize error: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _videoPlayerError = e.toString();
        _isVideoPlayerInitialized = false;
      });
    }
  }

  Future<void> _loadTracksWithRetry() async {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      _tracksLoading = true;
      _tracksLoadedOnce = false;
    });

    Map<int, String> audios = const {};
    Map<int, String> subs = const {};

    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        audios = await controller.getAudioTracks();
      } catch (_) {
        // Si aún no está inicializado, intentaremos de nuevo.
      }

      try {
        subs = await controller.getSpuTracks();
      } catch (_) {
        // Si aún no está inicializado, intentaremos de nuevo.
      }

      // Si ya hay al menos una pista, salimos.
      if (audios.isNotEmpty || subs.isNotEmpty) break;

      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (!mounted) return;
    setState(() {
      _audioTracks = audios;
      _subtitles = subs;
      _tracksLoading = false;
      _tracksLoadedOnce = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _castCurrentVideoAfterSessionStarted() async {
    final controller = _castController;
    if (!mounted || controller == null) return;

    try {
      // Cargamos el video en el dispositivo y luego le damos play.
      await controller.loadMedia(
        widget.videoUrl,
        title: widget.title,
      );
      await controller.play();
    } catch (e, st) {
      debugPrint('Cast error (load/play): $e');
      debugPrint('Cast stacktrace: $st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isCastSupported)
            IconButton(
              icon: const Icon(Icons.cast),
              tooltip: 'Enviar a TV',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Dispositivos disponibles',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Center(
                          child: ChromeCastButton(
                            size: 40,
                            onButtonCreated: (controller) {
                              _castController = controller;
                            },
                            onSessionStarted: () {
                              // Cuando se conecta la TV, cargamos y reproducimos el vídeo.
                              unawaited(_castCurrentVideoAfterSessionStarted());
                            },
                            onRequestFailed: (error) {
                              debugPrint('Cast request failed: $error');
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VideoScreen: web=$kIsWeb | platform=${defaultTargetPlatform.name}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            _isVlcSupported && _controller != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VlcPlayer(
                        controller: _controller!,
                        aspectRatio: 16 / 9,
                        placeholder: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.pause),
                            tooltip: 'Pausar / Reanudar',
                            onPressed: () async {
                              final playing = await _controller!.isPlaying();
                              if (playing == true) {
                                _lastPosition = await _controller!.getPosition();
                                await _controller!.pause();
                              } else {
                                if (_lastPosition != null) {
                                  await _controller!.setTime(
                                    _lastPosition!.inMilliseconds,
                                  );
                                }
                                await _controller!.play();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            tooltip: 'Parar',
                            onPressed: () async {
                              await _controller!.stop();
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.settings),
                            onSelected: (value) async {
                              if (value == 'none') return;
                              if (value.startsWith('audio_')) {
                                final id = int.parse(value.split('_')[1]);
                                await _controller!.setAudioTrack(id);
                              } else if (value.startsWith('sub_')) {
                                final id = int.parse(value.split('_')[1]);
                                await _controller!.setSpuTrack(id);
                              }
                            },
                            itemBuilder: (context) {
                              List<PopupMenuEntry<String>> items = [];

                              if (_tracksLoading && !_tracksLoadedOnce) {
                                items.add(
                                  const PopupMenuItem(
                                    value: 'none',
                                    enabled: false,
                                    child: Text('Cargando pistas...'),
                                  ),
                                );
                              } else if (_audioTracks.isEmpty &&
                                  _subtitles.isEmpty) {
                                items.add(
                                  const PopupMenuItem(
                                    value: 'none',
                                    enabled: false,
                                    child: Text('Sin pistas de audio/subtítulos'),
                                  ),
                                );
                              } else {
                                for (final entry in _audioTracks.entries) {
                                  items.add(
                                    PopupMenuItem(
                                      value: 'audio_${entry.key}',
                                      child: Text('Audio: ${entry.value}'),
                                    ),
                                  );
                                }

                                for (final entry in _subtitles.entries) {
                                  items.add(
                                    PopupMenuItem(
                                      value: 'sub_${entry.key}',
                                      child: Text('Sub: ${entry.value}'),
                                    ),
                                  );
                                }
                              }

                              return items;
                            },
                          ),
                        ],
                      ),
                    ],
                  )
                : _isVideoPlayerSupported &&
                        _videoPlayerController != null &&
                        (_isVideoPlayerInitialized ||
                            _videoPlayerError != null)
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isVideoPlayerInitialized)
                            AspectRatio(
                              aspectRatio:
                                  _videoPlayerController!.value.aspectRatio,
                              child: VideoPlayer(_videoPlayerController!),
                            )
                          else
                            const SizedBox(height: 1),

                          const SizedBox(height: 12),

                          if (_videoPlayerError != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Error cargando video: $_videoPlayerError',
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            const SizedBox.shrink(),

                          if (_isVideoPlayerInitialized)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  tooltip: 'Reproducir / Pausar',
                                  onPressed: () async {
                                    final isPlaying = _videoPlayerController!
                                        .value.isPlaying;
                                    if (isPlaying) {
                                      await _videoPlayerController!.pause();
                                    } else {
                                      await _videoPlayerController!.play();
                                    }
                                  },
                                ),
                              ],
                            ),

                          if (_isVideoPlayerInitialized)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Audio/Subtítulos elegibles: solo disponible con VLC (Android/iOS)',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Cargando video...',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Preparando reproductor...',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
          ],
        ),
      ),
    );
  }
}