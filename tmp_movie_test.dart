import 'package:filmoly/movie_utils.dart';

void main() {
  print('=== CASO 1: Búsqueda específica - Desperado (1995) ===');
  final movie1 = MovieReference(title: 'Desperado', year: 1995);
  final r1 = analyzeFileMatch(
      '/Videos/Accion/Desperado (1995).mkv', 'Accion', movie1,
      includeAllVideos: false);
  print('Confianza: ${r1.confidence}');
  print('Motivos:');
  for (var reason in r1.reasons) {
    print('  - $reason');
  }
  print('');

  print('=== CASO 2: Listado completo - Desperado (1995).mkv sin referencia ===');
  final movie2 = MovieReference(title: '', year: null);
  final r2 = analyzeFileMatch(
      '/Videos/Accion/(1995)Desperado.mkv', 'Accion', movie2,
      includeAllVideos: true);
  print('Confianza: ${r2.confidence}');
  print('Motivos:');
  for (var reason in r2.reasons) {
    print('  - $reason');
  }
  print('');

  print('=== CASO 3: Archivo simple (solo año) ===');
  final r3 = analyzeFileMatch('/Videos/1995.mkv', 'Videos', movie2,
      includeAllVideos: true);
  print('Confianza: ${r3.confidence}');
  print('Motivos:');
  for (var reason in r3.reasons) {
    print('  - $reason');
  }
  if (r3.reasons.isEmpty) print('  (ninguno)');
  print('');

  print('=== CASO 4: Archivo sin año ===');
  final r4 = analyzeFileMatch('/Videos/SomeMovie.mkv', 'Videos', movie2,
      includeAllVideos: true);
  print('Confianza: ${r4.confidence}');
  print('Motivos:');
  for (var reason in r4.reasons) {
    print('  - $reason');
  }
  if (r4.reasons.isEmpty) print('  (ninguno)');
  print('');

  print('=== CASO 5: Archivo con multipart ===');
  final r5 = analyzeFileMatch(
      '/Videos/Desperado (1995) Part 2.mkv', 'Videos', movie2,
      includeAllVideos: true);
  print('Confianza: ${r5.confidence}');
  print('Multipart: ${r5.isMultipart} (Parte ${r5.partNumber})');
  print('Motivos:');
  for (var reason in r5.reasons) {
    print('  - $reason');
  }
}
