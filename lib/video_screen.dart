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