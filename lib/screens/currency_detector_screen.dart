import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import 'package:http_parser/http_parser.dart';

class CurrencyDetectorScreen extends StatefulWidget {
  const CurrencyDetectorScreen({super.key});

  @override
  State<CurrencyDetectorScreen> createState() => _CurrencyDetectorScreenState();
}

class _CurrencyDetectorScreenState extends State<CurrencyDetectorScreen> {
  late CameraController _controller;
  late FlutterTts flutterTts;
  bool isDetecting = false;
  int totalAmount = 0;
  bool showBoundingBoxes = false;
  List<Recognition> currentRecognitions = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    flutterTts = FlutterTts();
    _speakInitialInstructions();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _speakInitialInstructions() async {
    await Future.delayed(const Duration(seconds: 1));
    await flutterTts.speak("Welcome to Currency Detector. Click at bottom half to get started");
  }

  Future<void> _speakCaptureInstructions() async {
    if (!showBoundingBoxes) {
      await flutterTts.speak("Click at bottom half of screen to capture and detect currency");
    }
  }

  Future<void> detectCurrency() async {
    if (isDetecting) return;
    
    if (showBoundingBoxes) {
      await flutterTts.speak("Starting new detection");
      setState(() {
        showBoundingBoxes = false;
        currentRecognitions = [];
      });
      await _speakCaptureInstructions();
      return;
    }

    setState(() {
      isDetecting = true;
    });

    try {
      await flutterTts.speak("Taking picture");
      print("Taking picture...");
      final XFile image = await _controller.takePicture();
      
      await flutterTts.speak("Processing image");
      print("Processing image: ${image.path}");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://34.100.220.102:8082/predict')
      );
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        )
      );

      request.headers.addAll({
        'Accept': 'application/json',
      });

      print("Sending request to server...");
      await flutterTts.speak("Detecting currency");
      final response = await request.send();
      final responseString = await response.stream.bytesToString();
      print("Server response code: ${response.statusCode}");
      print("Server response: $responseString");

      if (response.statusCode == 200) {
        final Map<String, dynamic> predictions = json.decode(responseString);
        List<Recognition> recognitions = [];
        int sum = 0;
        String detectedNotes = "";

        for (var prediction in predictions['predictions']) {
          if (prediction['confidence'] >= 0.25) {
            final bbox = prediction['bbox'];
            final rect = Rect.fromLTWH(
              bbox[0],
              bbox[1],
              bbox[2] - bbox[0],
              bbox[3] - bbox[1],
            );

            recognitions.add(
              Recognition(
                prediction['class'].toString(),
                prediction['class_name'],
                prediction['confidence'],
                rect,
              ),
            );

            int value = _getNoteValue(prediction['class_name']);
            sum += value;
            detectedNotes += "${prediction['class_name']}, ";
          }
        }

        if (recognitions.isNotEmpty) {
          setState(() {
            totalAmount = sum;
            showBoundingBoxes = true;
            currentRecognitions = recognitions;
          });

          await flutterTts.speak("Detected notes are $detectedNotes. Total amount is $sum rupees. Tap to continue for new detection");
        } else {
          print("No currencies detected");
          await flutterTts.speak("No currency detected. Please try again");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No currency detected')),
          );
        }
      } else {
        print("Server error: ${response.statusCode}");
        await flutterTts.speak("Server error occurred. Please try again");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e, stackTrace) {
      print("Error during detection: $e");
      print("Stack trace: $stackTrace");
      await flutterTts.speak("An error occurred. Please try again");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during detection: $e')),
      );
    } finally {
      setState(() {
        isDetecting = false;
      });
    }
  }

  int _getNoteValue(String label) {
    switch (label) {
      case "10":
        return 10;
      case "20":
        return 20;
      case "50":
        return 50;
      case "100":
        return 100;
      case "200":
        return 200;
      case "500":
        return 500;
      case "2000":
        return 2000;
      case "1":
        return 1000;
      case "5":
        return 5;
      case "2":
        return 2;
      case "10":
        return 10; 
      default:
        return 0;
    }
  }

  void _showCreatedByDialog() async {
    await flutterTts.speak("Opening credits page");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Created By',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildProfileCard(
                      'Puneeth',
                      '99220041457',
                      'assets/puneeth.png',
                    ),
                    _buildProfileCard(
                      'Kushwanth',
                      '99220041451',
                      'assets/kush.png',
                    ),
                    _buildProfileCard(
                      'Prasanth',
                      '99220041463',
                      'assets/prashant.png',
                    ),
                    _buildProfileCard(
                      'Nandini',
                      '99220041434',
                      'assets/nandini.png',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(String name, String regNo, String imagePath) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage(imagePath),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              regNo,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container();
    }
    
    _speakCaptureInstructions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Detector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              _showCreatedByDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                CameraPreview(_controller),
                if (showBoundingBoxes)
                  CustomPaint(
                    painter: BoundingBoxPainter(currentRecognitions),
                    child: Container(),
                  ),
              ],
            ),
          ),
          InkWell(
            onTap: isDetecting ? null : detectCurrency,
            child: Container(
              width: double.infinity,
              color: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total Amount: ₹$totalAmount',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isDetecting 
                      ? 'Detecting...' 
                      : (showBoundingBoxes ? 'Tap to Continue' : 'Tap to Capture & Detect'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Recognition> recognitions;

  BoundingBoxPainter(this.recognitions);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var recognition in recognitions) {
      if (recognition.location != null) {
        canvas.drawRect(recognition.location!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class Recognition {
  final String id;
  final String label;
  final double confidence;
  final Rect? location;

  Recognition(this.id, this.label, this.confidence, this.location);

  @override
  String toString() {
    return 'Recognition(label: $label, confidence: $confidence)';
  }
} 