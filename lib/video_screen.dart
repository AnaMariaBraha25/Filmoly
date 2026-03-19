import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

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

  // Listas de pistas disponibles
  Map<int, String> _audioTracks = const {};
  Map<int, String> _subtitles = const {};

  @override
  void initState() {
    super.initState();

    // Comprobamos si VLC se puede usar en esta plataforma
    _isVlcSupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (_isVlcSupported) {
      _controller = VlcPlayerController.network(
        widget.videoUrl,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );

      // Esperamos un momento para que el vídeo se inicialice y luego cargamos pistas
      Future.delayed(const Duration(seconds: 1), () async {
        if (_controller != null) {
          final audios = await _controller!.getAudioTracks();
          final subs = await _controller!.getSpuTracks();
          if (!mounted) return;
          setState(() {
            _audioTracks = audios;
            _subtitles = subs;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isVlcSupported && _controller != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.settings),
              onSelected: (value) {
                // Cambiar audio o subtítulo según se seleccione
                if (value.startsWith('audio_')) {
                  final id = int.parse(value.split('_')[1]);
                  _controller!.setAudioTrack(id);
                } else if (value.startsWith('sub_')) {
                  final id = int.parse(value.split('_')[1]);
                  _controller!.setSpuTrack(id);
                }
              },
              itemBuilder: (context) {
                List<PopupMenuEntry<String>> items = [];

                // Pistas de audio
                for (final entry in _audioTracks.entries) {
                  items.add(
                    PopupMenuItem(
                      value: 'audio_${entry.key}',
                      child: Text('Audio: ${entry.value}'),
                    ),
                  );
                }

                // Subtítulos
                for (final entry in _subtitles.entries) {
                  items.add(
                    PopupMenuItem(
                      value: 'sub_${entry.key}',
                      child: Text('Sub: ${entry.value}'),
                    ),
                  );
                }

                return items;
              },
            ),
        ],
      ),
      body: Center(
        child: _isVlcSupported && _controller != null
            ? VlcPlayer(
                controller: _controller!,
                aspectRatio: 16 / 9,
                placeholder: const Center(child: CircularProgressIndicator()),
              )
            : const Text(
                "VLC no soportado en esta plataforma",
                style: TextStyle(fontSize: 18),
              ),
      ),
    );
  }
}