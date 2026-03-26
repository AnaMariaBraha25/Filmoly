import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TMDBService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _apiKey = '591d6195509123d5a06d6172315bb318';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  
  final Dio _dio = Dio();
  
  TMDBService() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }
  
  /// Obtiene detalles completos de una película por TMDB ID
  Future<MovieDetails> getMovieDetails(String tmdbId) async {
    try {
      debugPrint('📡 TMDB: Obteniendo detalles para ID $tmdbId');
      
      final response = await _dio.get(
        '$_baseUrl/movie/$tmdbId',
        queryParameters: {
          'api_key': _apiKey,
          'language': 'es-ES',
          'append_to_response': 'images,videos,credits,watch/providers'
        },
      );
      
      debugPrint('✅ TMDB: Detalles obtenidos correctamente');
      return MovieDetails.fromJson(response.data);
    } catch (e) {
      debugPrint('❌ TMDB Error al obtener detalles: $e');
      rethrow;
    }
  }
  
  /// Obtiene imágenes y posters de una película
  Future<List<String>> getMovieImages(String tmdbId) async {
    try {
      debugPrint('📡 TMDB: Obteniendo imágenes para ID $tmdbId');
      
      final response = await _dio.get(
        '$_baseUrl/movie/$tmdbId/images',
        queryParameters: {'api_key': _apiKey},
      );
      
      final posters = (response.data['posters'] as List? ?? [])
          .map((p) => '$_imageBaseUrl${p['file_path']}')
          .toList();
      
      debugPrint('✅ TMDB: ${posters.length} imágenes obtenidas');
      return posters;
    } catch (e) {
      debugPrint('❌ TMDB Error al obtener imágenes: $e');
      return [];
    }
  }
  
  /// Obtiene dónde ver (streaming providers) para España
  Future<Map<String, dynamic>> getWatchProviders(String tmdbId) async {
    try {
      debugPrint('📡 TMDB: Obteniendo providers para ID $tmdbId');
      
      final response = await _dio.get(
        '$_baseUrl/movie/$tmdbId/watch/providers',
        queryParameters: {'api_key': _apiKey},
      );
      
      final results = response.data['results'] as Map? ?? {};
      final esData = (results['ES'] as Map?) ?? {};
      
      debugPrint('✅ TMDB: Providers obtenidos');
      return Map<String, dynamic>.from(esData);
    } catch (e) {
      debugPrint('❌ TMDB Error al obtener providers: $e');
      return {};
    }
  }
  
  /// Obtiene trailers y videos de una película
  Future<List<VideoResult>> getMovieVideos(String tmdbId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/movie/$tmdbId/videos',
        queryParameters: {
          'api_key': _apiKey,
          'language': 'es-ES'
        },
      );
      
      final videos = (response.data['results'] as List? ?? [])
          .map((v) => VideoResult.fromJson(v))
          .toList();
      
      return videos;
    } catch (e) {
      debugPrint('❌ TMDB Error al obtener videos: $e');
      return [];
    }
  }
}

/// Modelo para detalles de película
class MovieDetails {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final DateTime? releaseDate;
  final int? budget;
  final int? revenue;
  final int? runtime;
  final String? imdbId;
  final List<Genre> genres;
  final List<Cast> cast;
  final List<ProductionCompany> productionCompanies;
  final List<String> productionCountries;
  final String? homepage;
  final bool adult;
  final List<String> backdropImages;
  final List<String> posterImages;
  final Map<String, dynamic>? watchProviders;
  final Map<String, dynamic>? images;
  
  MovieDetails({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    this.releaseDate,
    this.budget,
    this.revenue,
    this.runtime,
    this.imdbId,
    required this.genres,
    required this.cast,
    required this.productionCompanies,
    required this.productionCountries,
    this.homepage,
    required this.adult,
    required this.backdropImages,
    required this.posterImages,
    this.watchProviders,
    this.images,
  });
  
  String get posterUrl => posterPath != null 
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : '';
  
  String get backdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w780$backdropPath'
      : '';
  
  String get budgetFormatted => budget != null && budget! > 0
      ? '\$${(budget! / 1000000).toStringAsFixed(1)}M'
      : 'No disponible';
  
  String get revenueFormatted => revenue != null && revenue! > 0
      ? '\$${(revenue! / 1000000).toStringAsFixed(1)}M'
      : 'No disponible';
  
  String get imdbUrl => imdbId != null && imdbId!.isNotEmpty
      ? 'https://www.imdb.com/title/$imdbId'
      : '';
  
  String get rottenTomatoesSearch => 'https://www.rottentomatoes.com/search?search=$title';
  
  String get formattedYear => releaseDate != null
      ? releaseDate!.year.toString()
      : 'Desconocido';
  
  String get genresFormatted => genres.isNotEmpty
      ? genres.map((g) => g.name).join(', ')
      : 'No disponible';
  
  String get productionCountriesFormatted => productionCountries.isNotEmpty
      ? productionCountries.join(', ')
      : 'No disponible';
  
  factory MovieDetails.fromJson(Map<String, dynamic> json) {
    // Extraer backdrops y posters de images si están disponibles
    final images = json['images'] as Map? ?? {};
    final backdropsList = (images['backdrops'] as List? ?? [])
        .take(5)
        .map((b) => 'https://image.tmdb.org/t/p/w780${b['file_path']}')
        .toList();
    
    final postersList = (images['posters'] as List? ?? [])
        .take(5)
        .map((p) => 'https://image.tmdb.org/t/p/w500${p['file_path']}')
        .toList();
    
    // Extraer países (ISO codes)
    final countries = (json['production_countries'] as List? ?? [])
        .map((c) => c['name'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toList();
    
    return MovieDetails(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'No disponible',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] ?? 0,
      releaseDate: json['release_date'] != null 
          ? DateTime.tryParse(json['release_date'])
          : null,
      budget: json['budget'] as int?,
      revenue: json['revenue'] as int?,
      runtime: json['runtime'] as int?,
      imdbId: json['imdb_id'],
      homepage: json['homepage'],
      adult: json['adult'] ?? false,
      genres: (json['genres'] as List? ?? [])
          .map((g) => Genre.fromJson(g))
          .toList(),
      cast: (json['credits']?['cast'] as List? ?? [])
          .take(10)
          .map((c) => Cast.fromJson(c))
          .toList(),
      productionCompanies: (json['production_companies'] as List? ?? [])
          .map((c) => ProductionCompany.fromJson(c))
          .toList(),
      productionCountries: countries,
      backdropImages: backdropsList,
      posterImages: postersList,
      watchProviders: json['watch/providers'],
      images: json['images'],
    );
  }
}

class Genre {
  final int id;
  final String name;
  
  Genre({required this.id, required this.name});
  
  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class ProductionCompany {
  final int id;
  final String name;
  final String? logoPath;
  final String? originCountry;
  
  ProductionCompany({
    required this.id,
    required this.name,
    this.logoPath,
    this.originCountry,
  });
  
  String get logoUrl => logoPath != null
      ? 'https://image.tmdb.org/t/p/w200$logoPath'
      : '';
  
  factory ProductionCompany.fromJson(Map<String, dynamic> json) {
    return ProductionCompany(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Producción desconocida',
      logoPath: json['logo_path'],
      originCountry: json['origin_country'],
    );
  }
}

class Cast {
  final int id;
  final String name;
  final String character;
  final String? profilePath;
  
  Cast({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });
  
  String get profileUrl => profilePath != null
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : '';
  
  factory Cast.fromJson(Map<String, dynamic> json) {
    return Cast(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Desconocido',
      character: json['character'] ?? 'Sin especificar',
      profilePath: json['profile_path'],
    );
  }
}

class VideoResult {
  final String id;
  final String name;
  final String key;
  final String type;
  final String site;
  
  VideoResult({
    required this.id,
    required this.name,
    required this.key,
    required this.type,
    required this.site,
  });
  
  bool get isYouTube => site.toLowerCase() == 'youtube';
  String get youTubeUrl => 'https://www.youtube.com/watch?v=$key';
  
  factory VideoResult.fromJson(Map<String, dynamic> json) {
    return VideoResult(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      key: json['key'] ?? '',
      type: json['type'] ?? '',
      site: json['site'] ?? '',
    );
  }
}
