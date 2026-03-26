import 'dart:io';

Future<List<String>> scanVideoFiles(List<String> paths) async {
  final videoFiles = <String>[];
  final supportedExtensions = {'mkv', 'mp4', 'avi', 'm4v'};

  for (String directoryPath in paths) {
    final directory = Directory(directoryPath);
    if (await directory.exists()) {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      ).handleError((_) {}, test: (_) => true)) {
        if (entity is! File) continue;
        final dotIndex = entity.path.lastIndexOf('.');
        if (dotIndex == -1) continue;
        final extension = entity.path.substring(dotIndex + 1).toLowerCase();
        if (supportedExtensions.contains(extension)) {
          videoFiles.add(entity.path);
        }
      }
    }
  }

  return videoFiles;
}