import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:heartland_photo_app/home_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:heartland_photo_app/annotation_screen.dart';

class MediaScreen extends StatefulWidget {
  final CameraDescription camera;
  final bool isVideo;
  final String mainFolderName;
  final String mainFolder;
  final String subFolder;
  final String? initialMediaPath;

  const MediaScreen({
    Key? key,
    required this.camera,
    required this.isVideo,
    required this.mainFolderName,
    required this.mainFolder,
    required this.subFolder,
    this.initialMediaPath,
  }) : super(key: key);

  @override
  _MediaScreenState createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String? _capturedMediaPath;
  bool _isRecording = false;
  VideoPlayerController? _videoPlayerController;
  bool _isCameraView = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMediaPath != null) {
      _isCameraView = false;
      _capturedMediaPath = widget.initialMediaPath;
      if (widget.isVideo) {
        _initializeVideoPlayer(widget.initialMediaPath!);
      }
    }
    _initializeCamera();
  }

  void _initializeCamera() {
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _initializeVideoPlayer(String videoPath) async {
    if (_isDisposed) return;

    // Dispose of the old controller if it exists
    await _videoPlayerController?.dispose();

    if (_isDisposed) return;

    // Create and initialize the new controller
    _videoPlayerController = VideoPlayerController.file(File(videoPath));

    try {
      await _videoPlayerController!.initialize();
      if (!_isDisposed) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing video player: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(directory.path, '${DateTime.now()}.png');
      await image.saveTo(imagePath);

      if (!_isDisposed) {
        setState(() {
          _capturedMediaPath = imagePath;
          _isCameraView = false;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _captureVideo() async {
    if (_isRecording) {
      final file = await _controller.stopVideoRecording();
      if (!_isDisposed) {
        setState(() {
          _isRecording = false;
          _capturedMediaPath = file.path;
          _isCameraView = false;
        });
        await _initializeVideoPlayer(file.path);
      }
    } else {
      try {
        await _initializeControllerFuture;
        await _controller.startVideoRecording();
        if (!_isDisposed) {
          setState(() {
            _isRecording = true;
          });
        }
      } catch (e) {
        print(e);
      }
    }
  }

  Future<void> _retakeMedia() async {
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
      _videoPlayerController = null;
    }

    if (!_isDisposed) {
      setState(() {
        _capturedMediaPath = null;
        _isRecording = false;
        _isCameraView = true;
      });
    }
  }

  Future<void> _switchToCapture() async {
    await _retakeMedia();
  }

  Future<void> _navigateToHome() async {
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _navigateToAnnotation() async {
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AnnotationScreen(
          mediaPath: _capturedMediaPath!,
          mainFolder: widget.mainFolder,
          mainFolderName: widget.mainFolderName,
          subFolder: widget.subFolder,
          cameras: [widget.camera],
          isVideo: widget.isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCameraView
            ? (widget.isVideo ? 'Capture Video' : 'Capture Photo')
            : (widget.isVideo ? 'Review Video' : 'Review Photo')),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: _navigateToHome,
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                if (_isCameraView)
                  CameraPreview(_controller)
                else if (widget.isVideo && _videoPlayerController != null)
                  _videoPlayerController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio:
                              _videoPlayerController!.value.aspectRatio,
                          child: VideoPlayer(_videoPlayerController!),
                        )
                      : const Center(child: CircularProgressIndicator())
                else if (_capturedMediaPath != null && !widget.isVideo)
                  Image.file(File(_capturedMediaPath!), fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Text(
                      _isCameraView
                          ? widget.isVideo
                              ? 'Tap the camera button to start/stop recording'
                              : 'Tap the camera button to take a photo'
                          : 'Tap use to annotate or new to capture another ${widget.isVideo ? 'video' : 'photo'}',
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
          if (_isCameraView)
            FloatingActionButton(
              heroTag: widget.isVideo ? 'capture_video' : 'capture_photo',
              child: Icon(widget.isVideo
                  ? (_isRecording ? Icons.stop : Icons.videocam)
                  : Icons.camera_alt),
              backgroundColor: _isRecording ? Colors.red : Colors.blueGrey[800],
              onPressed: widget.isVideo ? _captureVideo : _capturePhoto,
            )
          else ...[
            FloatingActionButton(
              heroTag: 'use_media',
              child: const Icon(Icons.upload),
              backgroundColor: Colors.green,
              onPressed: _navigateToAnnotation,
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              heroTag: 'new_media',
              child: const Icon(Icons.refresh),
              backgroundColor: Colors.yellow[700],
              onPressed: _switchToCapture,
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
