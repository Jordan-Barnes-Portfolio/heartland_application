import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:heartland_photo_app/home_screen.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

class AnnotationScreen extends StatefulWidget {
  final String mediaPath;
  final String mainFolderName;
  final String mainFolder;
  final String subFolder;
  final bool isVideo;
  final List<CameraDescription> cameras;
  final List<XFile>? additionalImages; // Add this field

  const AnnotationScreen({
    Key? key,
    required this.mediaPath,
    required this.mainFolderName,
    required this.mainFolder,
    required this.subFolder,
    required this.cameras,
    required this.isVideo,
    this.additionalImages, // Add this parameter
  }) : super(key: key);

  @override
  _AnnotationScreenState createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _isUploading = false;
  VideoPlayerController? _videoPlayerController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();
    _initSpeech();
    if (widget.isVideo) {
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_isDisposed) return;

    // Dispose of any existing controller
    await _videoPlayerController?.dispose();

    if (_isDisposed) return;

    _videoPlayerController = VideoPlayerController.file(File(widget.mediaPath));

    try {
      await _videoPlayerController!.initialize();
      if (!_isDisposed) {
        setState(() {});
        await _videoPlayerController!.play();
      }
    } catch (e) {
      print('Error initializing video player: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _speech.cancel();
    _textController.dispose();
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initSpeech();
    }
  }

  void _initSpeech() async {
    _speechInitialized = await _speech.initialize(
      onStatus: (status) {
        print('onStatus: $status');
        print('Mounted: $mounted');
        if (status == 'done' && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (errorNotification) {
        print('onError: $errorNotification');
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _toggleListening() async {
    if (!_speechInitialized) {
      _initSpeech();
    }

    if (_speechInitialized) {
      if (_isListening) {
        await _speech.stop();
        if (mounted) setState(() => _isListening = false);
      } else {
        setState(() => _isListening = true);
        try {
          var result = await _speech.listen(
            onResult: (result) {
              if (mounted) {
                setState(() {
                  if (result.finalResult) {
                    _textController.text += ' ' + result.recognizedWords;
                  }
                });
              }
            },
            listenMode: stt.ListenMode.confirmation,
            cancelOnError: true,
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
          );
          if (result == false) {
            if (mounted) setState(() => _isListening = false);
          }
        } catch (e) {
          print('Error starting to listen: $e');
          if (mounted) setState(() => _isListening = false);
        }
      }
    } else {
      print('Speech recognition not initialized');
    }
  }

  Future<void> _uploadMediaAndAnnotation() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Upload current media
      await _uploadSingleMedia(widget.mediaPath, _textController.text);

      // Upload additional images if any
      if (widget.additionalImages != null) {
        for (var image in widget.additionalImages!) {
          await _uploadSingleMedia(
              image.path, ''); // Empty description for additional images
        }
      }

      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload successful!')),
        );
      }

      // Clean up video player before navigation
      if (widget.isVideo && _videoPlayerController != null) {
        await _videoPlayerController!.pause();
        await _videoPlayerController!.dispose();
        _videoPlayerController = null;
      }

      if (!mounted) return;

      // Navigate back to HomeScreen instead of MediaScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            initialFolderId: widget.mainFolder,
            initialFolderName: widget
                .mainFolder, // You might need to pass this through from previous screens
            initialSubFolder: widget.subFolder,
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error uploading: $e');
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
    } finally {
      if (!_isDisposed) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _uploadSingleMedia(String mediaPath, String description) async {
    final String uniqueId = const Uuid().v4();
    final String fileName = widget.isVideo ? '$uniqueId.mp4' : '$uniqueId.jpg';
    final String storagePath =
        '${widget.mainFolder}/${widget.subFolder}/$fileName';

    final Reference storageRef =
        FirebaseStorage.instance.ref().child(storagePath);
    await storageRef.putFile(File(mediaPath));
    final String mediaUrl = await storageRef.getDownloadURL();

    final DocumentReference folderRef =
        FirebaseFirestore.instance.collection('folders').doc(widget.mainFolder);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot folderSnapshot = await transaction.get(folderRef);

      if (!folderSnapshot.exists) {
        throw Exception('Main folder does not exist');
      }

      Map<String, dynamic> data = folderSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> subFolders =
          Map<String, dynamic>.from(data['subFolders'] ?? {});

      if (!subFolders.containsKey(widget.subFolder)) {
        throw Exception('Sub-folder does not exist');
      }

      Map<String, dynamic> subFolderData =
          Map<String, dynamic>.from(subFolders[widget.subFolder]);
      Map<String, dynamic> mediaDescriptions =
          Map<String, dynamic>.from(subFolderData['photoDescriptions'] ?? {});
      List<String> mediaList = List<String>.from(subFolderData['photos'] ?? []);

      mediaDescriptions[mediaUrl] = description;
      mediaList.add(mediaUrl);

      subFolders[widget.subFolder] = {
        ...subFolderData,
        'photoDescriptions': mediaDescriptions,
        'photos': mediaList,
        'timestamps': {
          ...subFolderData['timestamps'] ?? {},
          mediaUrl: FieldValue.serverTimestamp(),
        }
      };

      transaction.update(folderRef, {'subFolders': subFolders});
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (bool value) async {
        if (_isListening) await _speech.stop();
        _isListening = false;
        if (_videoPlayerController != null) {
          await _videoPlayerController!.pause();
          await _videoPlayerController!.dispose();
          _videoPlayerController = null;
        }
        print('Pop invoked: $value');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Annotate ${widget.isVideo ? 'Video' : 'Image'}'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () async {
              if (_isListening) await _speech.stop();
              if (_videoPlayerController != null) {
                await _videoPlayerController!.pause();
                await _videoPlayerController!.dispose();
                _videoPlayerController = null;
              }
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    initialFolderId: widget.mainFolder,
                    initialFolderName: widget
                        .mainFolder, // You might need to pass this through from previous screens
                    initialSubFolder: widget.subFolder,
                  ),
                ),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ),
        body: Container(
          color: Colors.grey[100],
          child: Column(
            children: [
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.isVideo
                        ? (_videoPlayerController?.value.isInitialized ?? false)
                            ? AspectRatio(
                                aspectRatio:
                                    _videoPlayerController!.value.aspectRatio,
                                child: VideoPlayer(_videoPlayerController!),
                              )
                            : const Center(child: CircularProgressIndicator())
                        : Image.file(
                            File(widget.mediaPath),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Your speech will appear here',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blueGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.blueGrey[800]!, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(
                          _isListening ? 'Stop Recording' : 'Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isListening ? Colors.red : Colors.blueGrey[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _toggleListening,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Main Folder: ${widget.mainFolderName}\nSub-Folder: ${widget.subFolder}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_upload),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          _isUploading ? null : _uploadMediaAndAnnotation,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
