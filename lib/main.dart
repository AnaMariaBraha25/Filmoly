import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mi reproductor"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(Icons.movie, size: 80),

            SizedBox(height: 20),

            Text(
              "Bienvenido",
              style: TextStyle(fontSize: 24),
            ),

            SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                print("Ir al reproductor");
              },
              child: Text("Abrir reproductor"),
            ),
          ],
        ),
      ),
    );
  }
}
