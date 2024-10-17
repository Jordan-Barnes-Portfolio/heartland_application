import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:heartland_photo_app/home_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class PhotoScreen extends StatefulWidget {
  final CameraDescription camera;

  const PhotoScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _PhotoScreenState createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(directory.path, '${DateTime.now()}.png');
      await image.saveTo(imagePath);

      setState(() {
        _capturedImagePath = imagePath;
      });
    } catch (e) {
      print(e);
    }
  }

  void _retakePicture() {
    setState(() {
      _capturedImagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annotate Image'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => HomeScreen(),
              ),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                _capturedImagePath == null
                    ? CameraPreview(_controller)
                    : Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Text(
                      _capturedImagePath == null
                          ? 'Tap the camera button to take a photo'
                          : 'Tap use to proceed or retake for a new photo',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_capturedImagePath == null)
            FloatingActionButton(
              child: const Icon(Icons.camera_alt),
              backgroundColor: Colors.blueGrey[800],
              onPressed: _takePicture,
            )
          else ...[
            FloatingActionButton(
              child: const Icon(Icons.check),
              backgroundColor: Colors.green,
              onPressed: () {
                Navigator.of(context).pop(_capturedImagePath);
              },
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              child: const Icon(Icons.replay),
              backgroundColor: Colors.red,
              onPressed: _retakePicture,
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
