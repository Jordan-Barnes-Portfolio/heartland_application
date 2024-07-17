import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'photo_screen.dart';
import 'annotation_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo Annotation App'),
        backgroundColor: Colors.blueGrey[800],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueGrey[800]!, Colors.blueGrey[600]!],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                'Capture and Annotate',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Take a photo and add voice annotations',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 48),
              ElevatedButton.icon(
                icon: Icon(Icons.camera),
                label: Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {
                  final imagePath = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoScreen(camera: cameras.first),
                    ),
                  );
                  if (imagePath != null) {
                    // Use pushReplacement instead of push
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AnnotationScreen(imagePath: imagePath),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
