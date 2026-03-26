import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'video_metadata.dart';

class VideoInfoScreen extends StatefulWidget {
  const VideoInfoScreen({super.key});

  @override
  State<VideoInfoScreen> createState() => _VideoInfoScreenState();
}

class _VideoInfoScreenState extends State<VideoInfoScreen> {
  final TextEditingController _urlController = TextEditingController();
  VideoMetadata? _metadata;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedPath;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<bool> _ensureStoragePermission() async {
    final status = await Permission.videos.request();
    if (status.isGranted || status.isLimited) return true;
    final legacy = await Permission.storage.request();
    return legacy.isGranted || legacy.isLimited;
  }

  Future<void> _pickFile() async {
    try {
      final granted = await _ensureStoragePermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos denegados para acceder a archivos')),
        );
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedPath = result.files.first.path;
          _urlController.text = _selectedPath ?? '';
          _metadata = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al seleccionar archivo: $e';
      });
    }
  }

  Future<void> _analyzeVideo() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa una URL o selecciona un archivo';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _metadata = null;
    });

    try {
      final metadata = await getVideoMetadata(input);
      if (mounted) {
        setState(() {
          _metadata = metadata;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al analizar video: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis de Metadatos de Video'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de entrada
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Selecciona un video',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'URL del video o ruta del archivo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: _urlController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _urlController.clear();
                                  setState(() {
                                    _metadata = null;
                                    _selectedPath = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Seleccionar Archivo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _analyzeVideo,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.analytics),
                            label: const Text('Analizar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Mensaje de error
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),

            // Resultados de metadatos
            if (_metadata != null) ...[
              const SizedBox(height: 20),
              _buildMetadataCard(
                'Información General',
                [
                  ('Resolución', _metadata!.resolution),
                  ('Calidad', _metadata!.quality),
                  ('Tamaño', '${_metadata!.sizeMB.toStringAsFixed(2)} MB'),
                  ('Duración', '${_metadata!.duration.toStringAsFixed(2)} segundos'),
                ],
              ),
              const SizedBox(height: 16),
              _buildMetadataCard(
                '🎬 Video',
                [
                  ('Codec', _metadata!.videoCodec),
                  ('Bitrate', _metadata!.bitrate),
                  ('FPS', '${_metadata!.fps} (${_metadata!.frameRate})'),
                  ('Aspect Ratio', _metadata!.aspectRatio),
                ],
              ),
              const SizedBox(height: 16),
              _buildMetadataCard(
                '🔊 Audio',
                [
                  ('Idiomas',
                      _metadata!.audioLanguages.isEmpty ? 'No disponible' : _metadata!.audioLanguages.join(', ')),
                  ('Codecs',
                      _metadata!.audioCodecs.isEmpty ? 'No disponible' : _metadata!.audioCodecs.join(', ')),
                ],
              ),
              const SizedBox(height: 16),
              _buildMetadataCard(
                '💬 Subtítulos',
                [
                  ('Estado',
                      _metadata!.subtitles.isEmpty ? 'Sin subtítulos' : _metadata!.subtitles.join(', ')),
                ],
              ),
              const SizedBox(height: 20),
              // Botón para copiar todos los datos
              ElevatedButton.icon(
                onPressed: _copyAllMetadata,
                icon: const Icon(Icons.content_copy),
                label: const Text('Copiar Todos los Metadatos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ] else if (!_isLoading)
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.video_library,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Selecciona un video para analizar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(String title, List<(String, String)> items) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final (label, value) = entry.value;
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  if (index < items.length - 1)
                    const Divider(
                      height: 12,
                      color: Colors.grey,
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _copyAllMetadata() {
    if (_metadata == null) return;

    final text = '''═══════════════════════════════════════
        METADATOS DEL VIDEO
═══════════════════════════════════════

📊 INFORMACIÓN GENERAL
• Resolución: ${_metadata!.resolution}
• Calidad: ${_metadata!.quality}
• Tamaño: ${_metadata!.sizeMB.toStringAsFixed(2)} MB
• Duración: ${_metadata!.duration.toStringAsFixed(2)} segundos

🎬 VIDEO
• Codec: ${_metadata!.videoCodec}
• Bitrate: ${_metadata!.bitrate}
• FPS: ${_metadata!.fps} (${_metadata!.frameRate})
• Aspect Ratio: ${_metadata!.aspectRatio}

🔊 AUDIO
• Idiomas: ${_metadata!.audioLanguages.isEmpty ? 'No disponible' : _metadata!.audioLanguages.join(', ')}
• Codecs: ${_metadata!.audioCodecs.isEmpty ? 'No disponible' : _metadata!.audioCodecs.join(', ')}

💬 SUBTÍTULOS
• Estado: ${_metadata!.subtitles.isEmpty ? 'Sin subtítulos' : _metadata!.subtitles.join(', ')}

═══════════════════════════════════════''';

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metadatos copiados al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
