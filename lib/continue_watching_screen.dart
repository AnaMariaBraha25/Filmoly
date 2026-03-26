import 'package:flutter/material.dart';
import 'watch_progress.dart';
import 'video_screen.dart';

class ContinueWatchingScreen extends StatefulWidget {
  const ContinueWatchingScreen({super.key});

  @override
  State<ContinueWatchingScreen> createState() => _ContinueWatchingScreenState();
}

class _ContinueWatchingScreenState extends State<ContinueWatchingScreen> {
  late Future<List<WatchProgress>> _progressFuture;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _loadProgress() {
    setState(() {
      _progressFuture = WatchProgressManager.getInProgressMovies();
    });
  }

  String _formatTime(double seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _removeFromProgress(String videoUrl) async {
    await WatchProgressManager.removeProgress(videoUrl);
    _loadProgress();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Película removida del historial'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmRemove(WatchProgress progress) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Remover película',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Remover "${progress.title}" del historial?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remover',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeFromProgress(progress.videoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Continuar viendo'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<WatchProgress>>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error cargando películas: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final movies = snapshot.data ?? [];

          if (movies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.movie_outlined,
                    size: 80,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No hay películas en progreso',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Empieza a ver una película para verla aquí',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildMovieCard(movie);
            },
          );
        },
      ),
    );
  }

  Widget _buildMovieCard(WatchProgress progress) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: InkWell(
        onTap: () {
          // Navega a la pantalla de reproducción
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoScreen(
                videoUrl: progress.videoUrl,
                title: progress.title,
                initialPosition: Duration(seconds: progress.positionSeconds.toInt()),
              ),
            ),
          ).then((_) {
            // Recarga después de volver
            _loadProgress();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      progress.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton(
                    color: Colors.grey[800],
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text(
                          'Remover',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () => _confirmRemove(progress),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.progress / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ),
              const SizedBox(height: 8),
              // Información de tiempo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.progress.toStringAsFixed(1)}% visto',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${_formatTime(progress.positionSeconds)} / ${_formatTime(progress.durationSeconds)}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Última visto
              Text(
                'Visto: ${_formatLastWatched(progress.lastWatched)}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastWatched(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else {
      return dateTime.toString().split('.')[0]; // Fecha completa
    }
  }
}
