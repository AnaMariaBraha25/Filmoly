import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'search_paths_store.dart';

class SearchPathsScreen extends StatefulWidget {
  const SearchPathsScreen({super.key});

  @override
  State<SearchPathsScreen> createState() => _SearchPathsScreenState();
}

class _SearchPathsScreenState extends State<SearchPathsScreen> {
  final List<String> _searchPaths = [];

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
    if (normalizedPath != null) {
      setState(() {
        if (!_searchPaths.contains(normalizedPath)) {
          _searchPaths.add(normalizedPath);
        }
      });
      await SearchPathsStore.save(_searchPaths);
    }
  }

  void _removePath(int index) {
    setState(() {
      _searchPaths.removeAt(index);
    });
    SearchPathsStore.save(_searchPaths);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas de Búsqueda'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _searchPaths.isEmpty
                ? const Center(
                    child: Text(
                      'No hay rutas guardadas',
                      style: TextStyle(color: Colors.white),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addPath,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Añadir ruta'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  SearchPathsStore.save(_searchPaths);
                  Navigator.of(context).pop(_searchPaths);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Confirmar rutas'),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
    );
  }
}