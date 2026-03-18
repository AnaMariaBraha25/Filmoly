import 'package:flutter/material.dart';

class VideoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reproductor de Video"),
      ),
      body: Center(
        child: Text(
          "Reproductor",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}