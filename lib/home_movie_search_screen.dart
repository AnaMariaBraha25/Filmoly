import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'movie_utils.dart';
import 'search_results_screen.dart';
import 'video_screen.dart';
import 'search_paths_store.dart';

class HomeMovieSearchScreen extends StatefulWidget {
  const HomeMovieSearchScreen({super.key});

  @override
  State<HomeMovieSearchScreen> createState() => _HomeMovieSearchScreenState();
}

class _HomeMovieSearchScreenState extends State<HomeMovieSearchScreen> {
  final List<String> _searchPaths = [];
  final TextEditingController _webUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedPaths();
  }

  Future<void> _loadSavedPaths() async {
    final saved = await SearchPathsStore.load();
    if (!mounted) return;
    setState(() {
      _searchPaths
        ..clear()
        ..addAll(saved);
    });
  }

  Future<bool> _ensureStoragePermission() async {
    final status = await Permission.videos.request();
    if (status.isGranted || status.isLimited) return true;

    // Compatibilidad Android < 13
    final legacy = await Permission.storage.request();
    return legacy.isGranted || legacy.isLimited;
  }

  String _normalizeSelectedPath(String rawPath) {
    if (!rawPath.startsWith('content://')) return rawPath;

    final decoded = Uri.decodeFull(rawPath);
    final marker = 'primary:';
    final idx = decoded.indexOf(marker);
    if (idx == -1) return rawPath;
    final subPath = decoded.substring(idx + marker.length);
    return '/storage/emulated/0/$subPath';
  }

  Future<void> _addPath() async {
    try {
      final granted = await _ensureStoragePermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin permisos para leer vídeos del almacenamiento')),
        );
        return;
      }

      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      final normalizedPath =
          selectedDirectory != null ? _normalizeSelectedPath(selectedDirectory) : null;
      if (normalizedPath != null && !_searchPaths.contains(normalizedPath)) {
        setState(() {
          _searchPaths.add(normalizedPath);
        });
        await SearchPathsStore.save(_searchPaths);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar ruta: $e')),
        );
      }
    }
  }

  void _removePath(int index) {
    setState(() {
      _searchPaths.removeAt(index);
    });
    SearchPathsStore.save(_searchPaths);
  }

  void _searchVideos() {
    if (_searchPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregue al menos una ruta de búsqueda')),
      );
      return;
    }

    // En esta pantalla se busca cualquier vídeo de las rutas seleccionadas.
    final movie = MovieReference(
      title: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          searchPaths: _searchPaths,
          movie: movie,
          includeAllVideos: true,
        ),
      ),
    );
  }

  Future<void> _savePaths() async {
    await SearchPathsStore.save(_searchPaths);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rutas guardadas correctamente')),
    );
  }

  @override
  void dispose() {
    _webUrlController.dispose();
    super.dispose();
  }

  void _openWebUrl() {
    final url = _webUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce una URL para reproducir')),
      );
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL inválida. Debe tener http:// o https://')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoScreen(videoUrl: url, title: 'URL web'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda de Películas Locales'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _searchPaths.isEmpty
                ? const Center(
                    child: Text(
                      'No hay rutas de búsqueda agregadas.\nUse "Añadir ruta" para comenzar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchPaths.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(
                          Icons.folder,
                          color: Colors.white,
                        ),
                        title: Text(
                          _searchPaths[index],
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () => _removePath(index),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addPath,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Añadir ruta'),
                  ),
                ),
                if (kIsWeb) ...[
                  TextField(
                    controller: _webUrlController,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'URL de vídeo (solo web)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'https://.../desperado.mkv',
                      hintStyle: const TextStyle(color: Colors.white30),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openWebUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Reproducir URL en web'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savePaths,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Guardar rutas'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _searchVideos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Buscar vídeos'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
    );
  }
}