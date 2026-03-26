import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'video_screen.dart';
import 'movie_utils.dart';
import 'search_results_screen.dart';
import 'home_movie_search_screen.dart';
import 'search_paths_store.dart';
import 'video_info_screen.dart';
import 'continue_watching_screen.dart';
import 'movie_details_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('Main: initializing MediaKit...');
    MediaKit.ensureInitialized();
    debugPrint('Main: MediaKit initialized successfully.');
  } catch (e, st) {
    debugPrint('Main: MediaKit initialization failed: $e');
    debugPrint('$st');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video App',
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Vídeos con nombre, URL y TMDB ID (CORRECTOS - IDs verificados en TMDB)
  final List<Map<String, String>> videos = [
    {
      'title': 'Caza Legal (1995)',
      'url':
          'https://media.retroteca.org/Retroteca/PELICULAS/Dreddo/%281995%29%20Caza%20Legal.%20Andrew%20Sipes.%20ESTADOS%20UNIDOS%20%23122360%20%5B11859%5D%20tt0113010.mp4',
      'tmdbId': '11859', // Fair Game / Caza Legal (TMDB verificado)
    },
    {
      'title': 'Desperado (1995)',
      'url':
          'https://media.retroteca.org/Retroteca/PELICULAS/Dreddo/%281995%29%20Desperado.%20Robert%20Rodriguez.%20ESTADOS%20UNIDOS%2C%20MEXICO%20%2390911%20%5B1053600%5D%20tt0112851.mkv',
      'tmdbId': '8068', // Desperado (TMDB verificado)
    },
    {
      'title': 'Dororo (2007)',
      'url':
          'https://media.retroteca.org/Retroteca/PELICULAS/dororo/%282005%29%20Leyenda%20Mortal.%20Mark%20Duffield.%20TAILANDIA%20%23130906%20%5B51077%5D%20tt0436359.avi',
      'tmdbId': '16221', // Dororo (TMDB verificado - 2007)
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Reproductor de películas",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    const Icon(Icons.movie, size: 80, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      "SELECCIONE UNA PELÍCULA",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Botones para cada vídeo
                    for (var video in videos)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 200,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.grey[800], // Botón gris oscuro
                                  foregroundColor: Colors.white, // Texto blanco
                                ),
                                onPressed: () async {
                                  if (video['title']!.contains('Desperado')) {
                                    final selectedPaths = await SearchPathsStore.load();
                                    if (selectedPaths.isEmpty) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No hay rutas guardadas. Configúralas en "Gestionar rutas y buscar vídeos".',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    // Paso 2: buscar archivos para Desperado
                                    final movie = MovieReference(
                                      title: 'Desperado',
                                      year: 1995,
                                      tmdbId: '8078',
                                      imdbId: 'tt0112851',
                                    );

                                    if (!context.mounted) return;
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SearchResultsScreen(
                                          searchPaths: selectedPaths,
                                          movie: movie,
                                          autoPlayBestMatch: true,
                                        ),
                                      ),
                                    );
                                  } else {
                                    if (!mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VideoScreen(
                                          videoUrl: video['url']!,
                                          title: video['title']!,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Text(video['title']!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan[700],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MovieDetailsScreen(
                                        tmdbId: video['tmdbId']!,
                                        title: video['title']!,
                                      ),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.info, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 280,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.purple[800], // Botón púrpura para diferenciar
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const VideoInfoScreen(),
                              ),
                            );
                          },
                          child: const Text('📊 Analizar Metadatos de Video'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 280,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.orange[700], // Botón naranja para continuar viendo
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ContinueWatchingScreen(),
                              ),
                            );
                          },
                          child: const Text('▶ Continuar viendo'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 280,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.blue[800], // Botón azul para diferenciar
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const HomeMovieSearchScreen(),
                              ),
                            );
                          },
                          child: const Text('Gestionar rutas y buscar vídeos'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
