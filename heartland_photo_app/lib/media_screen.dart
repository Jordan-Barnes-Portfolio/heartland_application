import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:heartland_photo_app/home_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:video_player/video_player.dart';
<<<<<<< HEAD
=======
import 'package:heartland_photo_app/annotation_screen.dart';
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13

class MediaScreen extends StatefulWidget {
  final CameraDescription camera;
  final bool isVideo;
<<<<<<< HEAD

  const MediaScreen({Key? key, required this.camera, required this.isVideo})
      : super(key: key);
=======
  final String mainFolder;
  final String subFolder;
  final String? initialMediaPath; // Add this parameter

  const MediaScreen({
    Key? key,
    required this.camera,
    required this.isVideo,
    required this.mainFolder,
    required this.subFolder,
    this.initialMediaPath, // Optional parameter for existing media
  }) : super(key: key);
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13

  @override
  _MediaScreenState createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String? _capturedMediaPath;
  bool _isRecording = false;
  VideoPlayerController? _videoPlayerController;
<<<<<<< HEAD
=======
  bool _isCameraView = true;
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
=======
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
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

<<<<<<< HEAD
  @override
  void dispose() {
    _controller.dispose();
    _videoPlayerController?.dispose();
=======
  void _initializeVideoPlayer(String videoPath) {
    _videoPlayerController = VideoPlayerController.file(File(videoPath))
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController!.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
    }
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(directory.path, '${DateTime.now()}.png');
      await image.saveTo(imagePath);

      setState(() {
        _capturedMediaPath = imagePath;
<<<<<<< HEAD
=======
        _isCameraView = false;
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _captureVideo() async {
    if (_isRecording) {
      final file = await _controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _capturedMediaPath = file.path;
<<<<<<< HEAD
      });

      _videoPlayerController =
          VideoPlayerController.file(File(_capturedMediaPath!))
            ..initialize().then((_) {
              setState(() {});
              _videoPlayerController!.play();
            });
=======
        _isCameraView = false;
      });

      _initializeVideoPlayer(file.path);
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
    } else {
      try {
        await _initializeControllerFuture;
        await _controller.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print(e);
      }
    }
  }

  void _retakeMedia() {
<<<<<<< HEAD
    setState(() {
      _capturedMediaPath = null;
      _isRecording = false;
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
=======
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
      _videoPlayerController = null;
    }
    setState(() {
      _capturedMediaPath = null;
      _isRecording = false;
      _isCameraView = true;
    });
  }

  void _switchToCapture() {
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
      _videoPlayerController = null;
    }
    setState(() {
      _capturedMediaPath = null;
      _isRecording = false;
      _isCameraView = true;
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
<<<<<<< HEAD
        title: Text(widget.isVideo ? 'Capture Video' : 'Capture Photo'),
=======
        title: Text(_isCameraView
            ? (widget.isVideo ? 'Capture Video' : 'Capture Photo')
            : (widget.isVideo ? 'Review Video' : 'Review Photo')),
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
<<<<<<< HEAD
=======
            if (_videoPlayerController != null) {
              _videoPlayerController!.pause();
              _videoPlayerController!.dispose();
            }
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
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
<<<<<<< HEAD
                if (_capturedMediaPath == null)
                  CameraPreview(_controller)
                else if (widget.isVideo && _videoPlayerController != null)
                  AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController!),
                  )
                else if (!widget.isVideo)
=======
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
                else if (_capturedMediaPath != null)
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
                  Image.file(File(_capturedMediaPath!), fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Text(
<<<<<<< HEAD
                      _capturedMediaPath == null
                          ? widget.isVideo
                              ? 'Tap the camera button to start/stop recording'
                              : 'Tap the camera button to take a photo'
                          : 'Tap use to proceed or retake for a new ${widget.isVideo ? 'video' : 'photo'}',
=======
                      _isCameraView
                          ? widget.isVideo
                              ? 'Tap the camera button to start/stop recording'
                              : 'Tap the camera button to take a photo'
                          : 'Tap use to annotate or new to capture another ${widget.isVideo ? 'video' : 'photo'}',
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
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
<<<<<<< HEAD
          if (_capturedMediaPath == null)
=======
          if (_isCameraView)
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
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
<<<<<<< HEAD
              child: const Icon(Icons.check),
              backgroundColor: Colors.green,
              onPressed: () {
                Navigator.of(context).pop(_capturedMediaPath);
=======
              child: const Icon(Icons.edit),
              backgroundColor: Colors.green,
              onPressed: () {
                if (_videoPlayerController != null) {
                  _videoPlayerController!.pause();
                  _videoPlayerController!.dispose();
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnnotationScreen(
                      mediaPath: _capturedMediaPath!,
                      mainFolder: widget.mainFolder,
                      subFolder: widget.subFolder,
                      cameras: [widget.camera],
                      isVideo: widget.isVideo,
                    ),
                  ),
                );
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
              },
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
<<<<<<< HEAD
              heroTag: 'retake_media',
              child: const Icon(Icons.replay),
              backgroundColor: Colors.red,
              onPressed: _retakeMedia,
=======
              heroTag: 'new_media',
              child: const Icon(Icons.camera),
              backgroundColor: Colors.blue,
              onPressed: _switchToCapture,
>>>>>>> cd48af275cb52e79ce0029ca1d2e2876dcf83a13
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
