import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter_cast_video/flutter_cast_video.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  bool _isMediaKitSupported = false;

  ChromeCastController? _castController;
  Duration? _lastPosition;

  Map<int, String> _audioTracks = const {};
  Map<int, String> _subtitles = const {};
  bool _tracksLoading = false;
  bool _tracksLoadedOnce = false;

  Player? _mediaPlayer;
  VideoController? _mediaController;
  StreamSubscription<PlayerLog>? _mediaKitLogSub;
  bool _mediaKitReady = false;
  String? _mediaKitError;

  // Estado para el botón de reproducción/pausa VLC
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();

    _isVlcSupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    _isCastSupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    _isMediaKitSupported =
        kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

    if (_isVlcSupported) {
      _controller = VlcPlayerController.network(
        widget.videoUrl,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );

      _loadTracksWithRetry();
    } else if (_isMediaKitSupported) {
      _initMediaKitPlayer();
    }
  }

  Future<void> _initMediaKitPlayer() async {
    setState(() {
      _mediaKitReady = false;
      _mediaKitError = null;
    });

    try {
      final player = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
        ),
      );
      final controller = VideoController(player);

      _mediaKitLogSub?.cancel();
      _mediaKitLogSub = player.stream.log.listen((log) {
        if (!mounted) return;
        if (log.level == 'error' || log.level == 'warn') {
          setState(() {
            _mediaKitError = log.text;
          });
        }
      });

      if (!mounted) return;
      setState(() {
        _mediaPlayer = player;
        _mediaController = controller;
      });

      await player.open(Media(widget.videoUrl), play: false);
      await player.play();
      if (!mounted) return;
      setState(() {
        _mediaKitReady = true;
        _mediaKitError = null;
      });
    } catch (e, st) {
      debugPrint('media_kit open error: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _mediaKitError = e.toString();
        _mediaKitReady = false;
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
      } catch (_) {}
      try {
        subs = await controller.getSpuTracks();
      } catch (_) {}
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
    _mediaKitLogSub?.cancel();
    _mediaPlayer?.dispose();
    super.dispose();
  }

  Future<void> _castCurrentVideoAfterSessionStarted() async {
    final controller = _castController;
    if (!mounted || controller == null) return;

    try {
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        titleTextStyle: const TextStyle(color: Colors.white),
        centerTitle: true,
        title: Text(widget.title),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isCastSupported)
            IconButton(
              icon: const Icon(Icons.cast, color: Colors.white),
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
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                              icon: Icon(_isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow),
                              color: Colors.white,
                              tooltip: 'Pausar / Reanudar',
                              onPressed: () async {
                                final playing = (await _controller!.isPlaying()) ?? false;
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
                                setState(() {
                                  _isPlaying = !playing;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.stop),
                              color: Colors.white,
                              tooltip: 'Parar',
                              onPressed: () async {
                                await _controller!.stop();
                                setState(() {
                                  _isPlaying = false;
                                });
                              },
                            ),
                            // PopupMenuButton de audio
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.audiotrack,
                                  color: Colors.white),
                              onSelected: (value) async {
                                if (value == 'none') return;
                                if (value.startsWith('audio_')) {
                                  final id = int.parse(value.split('_')[1]);
                                  await _controller!.setAudioTrack(id);
                                }
                              },
                              itemBuilder: (context) {
                                if (_audioTracks.isEmpty) {
                                  return [
                                    const PopupMenuItem(
                                      value: 'none',
                                      enabled: false,
                                      child: Text('Sin pistas de audio',
                                          style: TextStyle(color: Colors.white)),
                                    ),
                                  ];
                                }
                                return _audioTracks.entries
                                    .map((e) => PopupMenuItem(
                                          value: 'audio_${e.key}',
                                          child: Text(e.value,
                                              style: const TextStyle(
                                                  color: Colors.white)),
                                        ))
                                    .toList();
                              },
                            ),
                            // PopupMenuButton de subtítulos
                            PopupMenuButton<String>(
                              icon:
                                  const Icon(Icons.subtitles, color: Colors.white),
                              onSelected: (value) async {
                                if (value == 'none') return;
                                if (value.startsWith('sub_')) {
                                  final id = int.parse(value.split('_')[1]);
                                  await _controller!.setSpuTrack(id);
                                }
                              },
                              itemBuilder: (context) {
                                if (_subtitles.isEmpty) {
                                  return [
                                    const PopupMenuItem(
                                      value: 'none',
                                      enabled: false,
                                      child: Text('Sin subtítulos',
                                          style: TextStyle(color: Colors.white)),
                                    ),
                                  ];
                                }
                                return _subtitles.entries
                                    .map((e) => PopupMenuItem(
                                          value: 'sub_${e.key}',
                                          child: Text(e.value,
                                              style: const TextStyle(
                                                  color: Colors.white)),
                                        ))
                                    .toList();
                              },
                            ),
                          ],
                        ),
                      ],
                    )
                  : _isMediaKitSupported && _mediaKitError != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Error cargando video (MediaKit): $_mediaKitError',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : _isMediaKitSupported &&
                              _mediaPlayer != null &&
                              _mediaController != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Video(
                                    controller: _mediaController!,
                                    controls: null,
                                    subtitleViewConfiguration:
                                        const SubtitleViewConfiguration(),
                                    pauseUponEnteringBackgroundMode: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow),
                                      tooltip: 'Reproducir / Pausar',
                                      onPressed: () async {
                                        await _mediaPlayer!.playOrPause();
                                      },
                                    ),
                                  ],
                                ),
                                if (_mediaKitError != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Text(
                                      'Error cargando video: $_mediaKitError',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                if (_mediaKitError == null && !_mediaKitReady)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Cargando video (MediaKit)...',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.white),
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
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
            ],
          ),
        ),
      ),
    );
  }
}