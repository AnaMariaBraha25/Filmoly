import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'video_scanner.dart';
import 'movie_utils.dart';
import 'video_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final List<String> searchPaths;
  final MovieReference movie;
  final bool includeAllVideos;
  final bool autoPlayBestMatch;

  const SearchResultsScreen({
    super.key,
    required this.searchPaths,
    required this.movie,
    this.includeAllVideos = false,
    this.autoPlayBestMatch = false,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  List<FileMatchResult> _results = [];
  bool _isLoading = true;
  Map<String, int> _groupCounts = {};
  bool _autoPlayLaunched = false;

  String _confidenceLabel(int confidence, List<String> reasons) {
    // IDs siempre alta
    if (reasons.contains('contiene TMDb ID') ||
        reasons.contains('contiene IMDb ID'))
      return 'alta';

    if (!widget.includeAllVideos) {
      // Modo búsqueda específica
      if (reasons.contains('título + año presentes')) return 'alta';
      if (reasons.contains('contiene título exacto en archivo') ||
          reasons.contains('contiene título exacto en carpeta'))
        return 'alta';
      if (reasons.contains('contiene año correcto')) return 'media';
      if (confidence >= 120) return 'alta';
      if (confidence >= 70) return 'media';
      if (confidence > 0) return 'baja';
    } else {
      // Modo listado completo: umbrales más accesibles
      if (reasons.contains('nombre con múltiples palabras')) {
        if (confidence >= 80) return 'alta';
        if (confidence >= 40) return 'media';
        return 'baja';
      }
      if (confidence >= 120) return 'alta';
      if (confidence >= 70) return 'media';
      if (confidence > 0) return 'baja';
    }

    if (reasons.isNotEmpty) return 'baja';

    return 'muy baja';
  }

  @override
  void initState() {
    super.initState();
    _scanFiles();
  }

  Future<void> _scanFiles() async {
    setState(() {
      _isLoading = true;
    });

    List<FileMatchResult> allResults = [];

    for (String path in widget.searchPaths) {
      try {
        List<String> files = await scanVideoFiles([path]);
        for (String filePath in files) {
          final parentFolder = _parentFolder(filePath, fallback: path);

          FileMatchResult result = analyzeFileMatch(
            filePath,
            parentFolder,
            widget.movie,
            includeAllVideos: widget.includeAllVideos,
          );
          if (widget.includeAllVideos) {
            result.reasons.removeWhere((r) => r == 'pasa filtro mínimo');
          }
          allResults.add(result);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error scanning $path: $e')));
        }
      }
    }

    if (widget.includeAllVideos) {
      allResults.sort(
        (a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
      );
    } else {
      // Filtrar confianza para evitar falsos positivos claros.
      allResults = allResults.where((r) {
        final hasIdMatch =
            r.reasons.contains('contiene TMDb ID') ||
            r.reasons.contains('contiene IMDb ID');
        final hasTitleYear =
            r.reasons.contains('título + año presentes') ||
            (r.reasons.contains('contiene título exacto en archivo') &&
                r.reasons.contains('contiene año correcto')) ||
            (r.reasons.contains('contiene título exacto en carpeta') &&
                r.reasons.contains('contiene año correcto'));
        return hasIdMatch || hasTitleYear || r.confidence >= 40;
      }).toList();
      allResults.sort((a, b) {
        int cmp = b.confidence.compareTo(a.confidence);
        if (cmp != 0) return cmp;
        if (a.multipartGroup != null && b.multipartGroup != null) {
          cmp = a.multipartGroup!.compareTo(b.multipartGroup!);
          if (cmp != 0) return cmp;
          if (a.partNumber != null && b.partNumber != null) {
            return a.partNumber!.compareTo(b.partNumber!);
          }
        }
        return 0;
      });
    }

    // Contar grupos multipart
    _groupCounts = {};
    for (var r in allResults) {
      if (r.multipartGroup != null) {
        _groupCounts[r.multipartGroup!] =
            (_groupCounts[r.multipartGroup!] ?? 0) + 1;
      }
    }

    setState(() {
      _results = allResults;
      _isLoading = false;
    });

    if (widget.autoPlayBestMatch &&
        !_autoPlayLaunched &&
        allResults.isNotEmpty) {
      _autoPlayLaunched = true;
      if (!mounted) return;

      final best = allResults.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allResults.length > 1
                ? 'Se encontraron ${allResults.length} resultados. Reproduciendo la mejor coincidencia.'
                : 'Reproduciendo coincidencia encontrada.',
          ),
        ),
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VideoScreen(videoUrl: best.filePath, title: widget.movie.title),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.includeAllVideos
              ? 'Vídeos encontrados'
              : 'Resultados para ${widget.movie.title}',
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _results.isEmpty
          ? Center(
              child: Text(
                widget.includeAllVideos
                    ? 'No se encontraron vídeos en las rutas seleccionadas'
                    : 'No se encontraron archivos coincidentes',
                style: TextStyle(color: Colors.white),
              ),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                FileMatchResult result = _results[index];
                return ListTile(
                  title: Text(
                    result.fileName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ruta: ${result.filePath}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        'Coincidencia: ${_confidenceLabel(result.confidence, result.reasons)} (${result.confidence})',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Motivos: ${result.reasons.isNotEmpty ? result.reasons.join(', ') : 'sin criterios específicos'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (result.isMultipart)
                        Text(
                          result.partNumber != null
                              ? 'Parte ${result.partNumber} de película (multipart)'
                              : 'Parte de película (multipart)',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      if (result.multipartGroup != null &&
                          (_groupCounts[result.multipartGroup!] ?? 0) > 1)
                        Text(
                          'Relacionado con otras ${(_groupCounts[result.multipartGroup!] ?? 0) - 1} partes',
                          style: const TextStyle(color: Colors.blue),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        tooltip: 'Reproducir',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoScreen(
                                videoUrl: result.filePath,
                                title: widget.includeAllVideos
                                    ? result.fileName
                                    : widget.movie.title,
                              ),
                            ),
                          );
                        },
                      ),
                      if (kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.open_in_new, color: Colors.white70),
                          tooltip: 'Abrir en reproductor externo',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoScreen(
                                  videoUrl: result.filePath,
                                  title: widget.includeAllVideos
                                      ? result.fileName
                                      : widget.movie.title,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoScreen(
                          videoUrl: result.filePath,
                          title: widget.includeAllVideos
                              ? result.fileName
                              : widget.movie.title,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      backgroundColor: Colors.black,
    );
  }
}

String _parentFolder(String path, {required String fallback}) {
  final normalized = path.replaceAll('\\', '/');
  final lastIndex = normalized.lastIndexOf('/');
  if (lastIndex <= 0) return fallback;
  return normalized.substring(0, lastIndex);
}
