class MovieReference {
  final String title;
  final String? tmdbId;
  final String? imdbId;
  final int? year;

  MovieReference({required this.title, this.tmdbId, this.imdbId, this.year});
}

class FileMatchResult {
  final String filePath;
  final String fileName;
  final String parentFolder;
  final int confidence;
  final List<String> reasons;
  final bool isMultipart;
  final String? multipartGroup;
  final int? partNumber;

  FileMatchResult({
    required this.filePath,
    required this.fileName,
    required this.parentFolder,
    required this.confidence,
    required this.reasons,
    required this.isMultipart,
    this.multipartGroup,
    this.partNumber,
  });
}

/// Normaliza un nombre de archivo de película para comparación
String normalizeFileName(String input) {
  String normalized = input.toLowerCase();
  normalized = normalized.replaceAll(RegExp(r'\.(mkv|mp4|avi|m4v)$'), '');
  normalized = normalized.replaceAll(RegExp(r'[._-]'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[()\[\]]'), ' ');
  return normalized.trim();
}

/// Verifica si un nombre normalizado pasa el filtro mínimo comparado con una referencia de película
bool passesMinimumFilter(String normalizedName, MovieReference movie) {
  String title = movie.title.toLowerCase().trim();

  // Si no se especifica ninguna referencia, aceptar todo (modo "buscar vídeos").
  if (title.isEmpty &&
      movie.tmdbId == null &&
      movie.imdbId == null &&
      movie.year == null) {
    return true;
  }

  if (title.isNotEmpty && normalizedName.contains(title)) return true;
  if (movie.tmdbId != null && normalizedName.contains(movie.tmdbId!))
    return true;
  if (movie.imdbId != null && normalizedName.contains(movie.imdbId!))
    return true;
  return false;
}

/// Analiza si un archivo coincide con una referencia de película y calcula confianza
FileMatchResult analyzeFileMatch(
  String filePath,
  String parentFolder,
  MovieReference movie, {
  bool includeAllVideos = false,
}) {
  final fileName = _basename(filePath);
  final normalizedFileName = normalizeFileName(fileName);
  final normalizedParentFolder = normalizeFileName(parentFolder);

  final title = movie.title.toLowerCase().trim();
  final tmdbId = movie.tmdbId;
  final imdbId = movie.imdbId;

  final reasons = <String>[];
  int confidence = 0;

  // 1. Verificar coincidencias de ID (muy fuerte)
  final tmdbInFile = tmdbId != null && normalizedFileName.contains(tmdbId);
  final imdbInFile = imdbId != null && normalizedFileName.contains(imdbId);

  if (tmdbInFile) {
    confidence += 100;
    reasons.add('contiene TMDb ID');
  }
  if (imdbInFile) {
    confidence += 100;
    reasons.add('contiene IMDb ID');
  }

  // 2. Verificar coincidencias de título
  final titleInFile = title.isNotEmpty && normalizedFileName.contains(title);
  final titleInFolder =
      title.isNotEmpty && normalizedParentFolder.contains(title);

  if (titleInFile) {
    confidence += 60;
    reasons.add('contiene título exacto en archivo');
  }
  if (titleInFolder) {
    confidence += 10;
    reasons.add('contiene título exacto en carpeta');
  }

  // 3. Detección de años
  final yearRegex = RegExp(r'\b(19|20|21)\d{2}\b');
  final fileYears = yearRegex.allMatches(normalizedFileName);
  final folderYears = yearRegex.allMatches(normalizedParentFolder);
  final years = <int>{};
  years.addAll(fileYears.map((m) => int.parse(m.group(0)!)));
  years.addAll(folderYears.map((m) => int.parse(m.group(0)!)));

  final yearMatches = movie.year != null && years.contains(movie.year);
  final hasDifferentYear =
      movie.year != null && years.isNotEmpty && !years.contains(movie.year);

  if (yearMatches) {
    confidence += 25;
    reasons.add('contiene año correcto');
  }

  // 4. Penalizar por año incorrecto
  if (hasDifferentYear && (titleInFile || titleInFolder)) {
    confidence -= 40;
    reasons.add('otro año encontrado');
  }

  // 5. Bonificación por título + año juntos
  if ((titleInFile || titleInFolder) && yearMatches) {
    confidence += 30;
    reasons.add('título + año presentes');
  }

  // 6. Coincidencia parcial si no hay título exacto
  if (!titleInFile && !titleInFolder && tmdbId == null && imdbId == null) {
    final titleTokens = title
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (titleTokens.isNotEmpty) {
      int tokenMatches = 0;
      for (final token in titleTokens) {
        if (normalizedFileName.contains(token)) {
          tokenMatches++;
        }
      }
      if (tokenMatches > 0) {
        confidence += tokenMatches * 10;
        reasons.add(
          'coincidencia parcial ($tokenMatches palabra${tokenMatches > 1 ? 's' : ''})',
        );
      }
    }
  }

  // 6. En modo listado completo sin referencia, detectar películas probables por patrón
  if (includeAllVideos &&
      title.isEmpty &&
      tmdbId == null &&
      imdbId == null &&
      years.isNotEmpty) {
    // Si detecta año en el archivo, sumar puntos por año
    confidence += 25;
    reasons.add('año detectado en archivo');

    // Si tiene múltiples palabras en el nombre, incrementar confianza por estructura
    final words = normalizedFileName
        .split(' ')
        .where((w) => w.isNotEmpty && w.length > 1)
        .toList();
    if (words.length > 1) {
      confidence += 60; // Estructura de película probable
      reasons.add('nombre con múltiples palabras');
    }
  }

  // 7. Detección de multipart (marcar pero no sumar puntos)
  final multipartRegex = RegExp(
    r'\b(?:part|pt|cd|disc|disk)\s*0*(\d+)\b',
    caseSensitive: false,
  );
  final multipartMatch = multipartRegex.firstMatch(normalizedFileName);
  final isMultipart = multipartMatch != null;
  String? multipartGroup;
  int? partNumber;

  if (multipartMatch != null) {
    partNumber = int.parse(multipartMatch.group(1)!);
    final suffix = multipartMatch.group(0)!;
    multipartGroup = fileName
        .replaceFirst(RegExp(suffix, caseSensitive: false), '')
        .trim();
    multipartGroup = multipartGroup.replaceAll(RegExp(r'[.\s]+$'), '');
    reasons.add('multipart: parte $partNumber');
  }

  // 8. Verificar si pasó filtro mínimo
  final normalizedForFilter = '$normalizedFileName $normalizedParentFolder';
  final passesMinimum = passesMinimumFilter(normalizedForFilter, movie);

  if (!passesMinimum) {
    // Si no pasa el filtro mínimo, rechazar completamente
    confidence = 0;
    reasons.clear();
    reasons.add('no coincide con criterios mínimos');
  } else {
    if (!includeAllVideos) {
      if (!reasons.contains('pasa filtro mínimo')) {
        reasons.insert(0, 'pasa filtro mínimo');
      }
    }
  }

  if (confidence < 0) confidence = 0;

  return FileMatchResult(
    filePath: filePath,
    fileName: fileName,
    parentFolder: parentFolder,
    confidence: confidence,
    reasons: reasons,
    isMultipart: isMultipart,
    multipartGroup: multipartGroup,
    partNumber: partNumber,
  );
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final idx = normalized.lastIndexOf('/');
  return idx >= 0 ? normalized.substring(idx + 1) : normalized;
}
