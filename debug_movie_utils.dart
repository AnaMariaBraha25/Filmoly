import 'package:filmoly/movie_utils.dart';

void main() {
  final movie = MovieReference(title: 'Desperado', year: 1995);
  final filePath = '/Videos/Accion/Desperado (1995).mkv';
  final parentFolder = '/Videos/Accion';
  final result = analyzeFileMatch(filePath, parentFolder, movie);
  print('confidence=${result.confidence}');
  print('reasons=${result.reasons}');

  final movie2 = MovieReference(title: '', year: null);
  final filePath2 = '/Videos/Accion/(1995)Desperado.mkv';
  final parentFolder2 = '/Videos/Accion';
  final result2 = analyzeFileMatch(filePath2, parentFolder2, movie2);
  print('confidence2=${result2.confidence}');
  print('reasons2=${result2.reasons}');
}
