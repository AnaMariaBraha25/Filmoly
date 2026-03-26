import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/tmdb_service.dart';

class MovieDetailsScreen extends StatefulWidget {
  final String tmdbId;
  final String title;

  const MovieDetailsScreen({
    super.key,
    required this.tmdbId,
    required this.title,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  late TMDBService _tmdbService;
  MovieDetails? _movieDetails;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedImageIndex = 0;
  String _currentGallery = 'posters'; // 'posters' o 'backdrops'

  @override
  void initState() {
    super.initState();
    _tmdbService = TMDBService();
    _loadMovieDetails();
  }

  Future<void> _loadMovieDetails() async {
    try {
      debugPrint('🔄 Cargando detalles para TMDB ID: ${widget.tmdbId}');
      final details = await _tmdbService.getMovieDetails(widget.tmdbId);
      debugPrint('✅ Detalles cargados: ${details.title}');
      debugPrint('   - Posters: ${details.posterImages.length}');
      debugPrint('   - Backdrops: ${details.backdropImages.length}');
      debugPrint('   - Productoras: ${details.productionCompanies.length}');
      debugPrint('   - IMDb ID: ${details.imdbId}');
      
      if (mounted) {
        setState(() {
          _movieDetails = details;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('❌ Error cargando detalles de película:');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $st');
      
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar: $e\n\nTMDB ID: ${widget.tmdbId}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _movieDetails == null
                  ? const Center(
                      child: Text(
                        'No se pudieron cargar los detalles',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Galería de imágenes mejorada
                          _buildImageGallery(),
                          const SizedBox(height: 16),

                          // Información expandida
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Rating
                                _buildRatingCard(),
                                const SizedBox(height: 12),

                                // Información básica
                                _buildBasicInfoCard(),
                                const SizedBox(height: 12),

                                // Enlaces externos
                                _buildExternalLinksCard(),
                                const SizedBox(height: 12),

                                // Información financiera
                                _buildFinancialInfoCard(),
                                const SizedBox(height: 12),

                                // Géneros
                                _buildGenresCard(),
                                const SizedBox(height: 12),

                                // Productoras
                                if (_movieDetails!.productionCompanies.isNotEmpty)
                                  _buildProductionCompaniesCard(),
                                if (_movieDetails!.productionCompanies.isNotEmpty)
                                  const SizedBox(height: 12),

                                // Países
                                if (_movieDetails!.productionCountries.isNotEmpty)
                                  _buildProductionCountriesCard(),
                                if (_movieDetails!.productionCountries.isNotEmpty)
                                  const SizedBox(height: 12),

                                // Sinopsis
                                _buildDescriptionCard(),
                                const SizedBox(height: 12),

                                // Elenco
                                if (_movieDetails!.cast.isNotEmpty)
                                  _buildCastCard(),
                                if (_movieDetails!.cast.isNotEmpty)
                                  const SizedBox(height: 12),

                                // Dónde ver
                                _buildWatchProvidersCard(),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildImageGallery() {
    final currentImages = _currentGallery == 'posters'
        ? _movieDetails!.posterImages
        : _movieDetails!.backdropImages;

    if (currentImages.isEmpty) {
      if (_movieDetails!.posterUrl.isNotEmpty) {
        return Container(
          width: MediaQuery.of(context).size.width,
          height: 400,
          color: Colors.black,
          child: Image.network(
            _movieDetails!.posterUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 50),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Imagen principal
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.all(0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      currentImages[_selectedImageIndex],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(Icons.broken_image, color: Colors.white),
                          ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Container(
            height: 400,
            width: MediaQuery.of(context).size.width,
            color: Colors.black,
            child: Image.network(
              currentImages[_selectedImageIndex],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
            ),
          ),
        ),

        // Controles de galería
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Botones para cambiar entre posters y backdrops
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_movieDetails!.posterImages.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentGallery = 'posters';
                          _selectedImageIndex = 0;
                        });
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Posters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentGallery == 'posters'
                            ? Colors.orange
                            : Colors.grey[700],
                      ),
                    ),
                  if (_movieDetails!.backdropImages.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentGallery = 'backdrops';
                          _selectedImageIndex = 0;
                        });
                      },
                      icon: const Icon(Icons.landscape),
                      label: const Text('Fondos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentGallery == 'backdrops'
                            ? Colors.orange
                            : Colors.grey[700],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Miniaturas
              if (currentImages.length > 1)
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    itemCount: currentImages.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImageIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedImageIndex == index
                                  ? Colors.orange
                                  : Colors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              currentImages[index],
                              fit: BoxFit.cover,
                              width: 60,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 30,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingCard() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rating',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _movieDetails!.voteAverage.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: ' / 10',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Text(
              '${_movieDetails!.voteCount} votos',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_movieDetails!.releaseDate != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Estreno: ${_movieDetails!.releaseDate!.day}/${_movieDetails!.releaseDate!.month}/${_movieDetails!.releaseDate!.year}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            if (_movieDetails!.runtime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Duración: ${_movieDetails!.runtime} minutos',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExternalLinksCard() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Links Externos',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_movieDetails!.imdbId != null && _movieDetails!.imdbId!.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchUrl(_movieDetails!.imdbUrl),
                      icon: const Icon(Icons.link),
                      label: const Text('IMDb'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[800],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchUrl(_movieDetails!.rottenTomatoesSearch),
                    icon: const Icon(Icons.search),
                    label: const Text('Rotten Tom.'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialInfoCard() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información Financiera',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Presupuesto', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      _movieDetails!.budgetFormatted,
                      style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recaudación', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      _movieDetails!.revenueFormatted,
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenresCard() {
    if (_movieDetails!.genres.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Géneros',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _movieDetails!.genres
                  .map(
                    (genre) => Chip(
                      label: Text(genre.name),
                      backgroundColor: Colors.orange[700],
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionCompaniesCard() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productoras',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _movieDetails!.productionCompanies
                  .map((company) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            if (company.logoUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    company.logoUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.business,
                                              color: Colors.grey, size: 20),
                                        ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    company.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (company.originCountry != null)
                                    Text(
                                      company.originCountry!,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionCountriesCard() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Países de Origen',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _movieDetails!.productionCountries
                  .map(
                    (country) => Chip(
                      label: Text(country),
                      backgroundColor: Colors.blueAccent[700],
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    if (_movieDetails!.overview.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sinopsis',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _movieDetails!.overview,
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCastCard() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elenco Principal',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _movieDetails!.cast.length,
                itemBuilder: (context, index) {
                  final actor = _movieDetails!.cast[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: actor.profileUrl.isNotEmpty
                              ? Image.network(
                                  actor.profileUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.person, color: Colors.grey),
                                      ),
                                )
                              : Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.person, color: Colors.grey),
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          actor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          actor.character,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchProvidersCard() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dónde Ver (España)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_movieDetails!.watchProviders != null &&
                (_movieDetails!.watchProviders!['flatrate'] != null ||
                    _movieDetails!.watchProviders!['rent'] != null ||
                    _movieDetails!.watchProviders!['buy'] != null))
              _buildWatchProvidersList()
            else
              const Text(
                'Información de streaming no disponible para España',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchProvidersList() {
    final flatrate =
        _movieDetails!.watchProviders!['flatrate'] as List? ?? [];
    final rent = _movieDetails!.watchProviders!['rent'] as List? ?? [];
    final buy = _movieDetails!.watchProviders!['buy'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (flatrate.isNotEmpty) ...[
          const Text(
            '📺 Ver con suscripción:',
            style: TextStyle(color: Colors.greenAccent, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: flatrate.map((p) {
              final name = p['provider_name'] ?? 'Desconocido';
              return Chip(
                label: Text(name, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.greenAccent[700],
                labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (rent.isNotEmpty) ...[
          const Text(
            '🎬 Alquilar:',
            style: TextStyle(color: Colors.blueAccent, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: rent.map((p) {
              final name = p['provider_name'] ?? 'Desconocido';
              return Chip(
                label: Text(name, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.blueAccent[700],
                labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (buy.isNotEmpty) ...[
          const Text(
            '💳 Comprar:',
            style: TextStyle(color: Colors.purpleAccent, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: buy.map((p) {
              final name = p['provider_name'] ?? 'Desconocido';
              return Chip(
                label: Text(name, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.purpleAccent[700],
                labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
