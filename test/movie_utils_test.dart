import 'package:flutter_test/flutter_test.dart';
import 'package:filmoly/movie_utils.dart';

void main() {
  test('analyzeFileMatch returns strong match for desperado', () {
    final movie = MovieReference(title: 'Desperado', year: 1995);
    final result = analyzeFileMatch('/Videos/Accion/Desperado (1995).mkv', '/Videos/Accion', movie);
    print('R=, reasons=');
    expect(result.confidence, greaterThan(0));
    expect(result.reasons, contains('contiene título en archivo'));
    expect(result.reasons, contains('contiene año correcto'));
  });
}
