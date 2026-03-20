import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'video_screen.dart';

void main() {
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

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  // Vídeos con nombre y URL
  final List<Map<String, String>> videos = [
    {
      'title': 'Dreddo (MP4)',
      'url':
          'https://media.retroteca.org/Retroteca/PELICULAS/Dreddo/%281995%29%20Caza%20Legal.%20Andrew%20Sipes.%20ESTADOS%20UNIDOS%20%23122360%20%5B11859%5D%20tt0113010.mp4',
    },
    {
      'title': 'Desperado (MKV)',
      'url':
          'https://media.retroteca.org/Retroteca/PELICULAS/Dreddo/%281995%29%20Desperado.%20Robert%20Rodriguez.%20ESTADOS%20UNIDOS%2C%20MEXICO%20%2390911%20%5B1053600%5D%20tt0112851.mkv',
    },
    {
      'title': 'Dororo (AVI)',
      'url':
          'https://media.retroteca.org/Retroteca/PELICULAS/dororo/%282005%29%20Leyenda%20Mortal.%20Mark%20Duffield.%20TAILANDIA%20%23130906%20%5B51077%5D%20tt0436359.avi',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reproductor de películas"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Plataforma: ${defaultTargetPlatform.name} | web=$kIsWeb',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),

            Icon(Icons.movie, size: 80),
            SizedBox(height: 20),
            Text(
              "SELECCIONE UNA PELÍCULA",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),

            // Botones para cada vídeo
            for (var video in videos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoScreen(
                          videoUrl: video['url']!,
                          title: video['title']!,
                        ),
                      ),
                    );
                  },
                  child: Text(video['title']!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
