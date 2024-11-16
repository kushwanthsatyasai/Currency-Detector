import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_image/flutter_image.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:flutter_image/flutter_image.dart' as img;
import 'package:flutter/material.dart';

class CurrencyDetectorScreen extends StatefulWidget {
  const CurrencyDetectorScreen({super.key});

  @override
  State<CurrencyDetectorScreen> createState() => _CurrencyDetectorScreenState();
}

class _CurrencyDetectorScreenState extends State<CurrencyDetectorScreen> {
  late CameraController _controller;
  late FlutterTts flutterTts;
  bool isDetecting = false;
  List<dynamic> recognitions = [];
  int totalAmount = 0;
  bool showBoundingBoxes = false;
  List<dynamic> currentRecognitions = [];
  late Interpreter _interpreter;
  late List<String> _labels;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
    flutterTts = FlutterTts();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadModel() async {
    try {
      print("Loading model...");
      // Load model
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      print("Model input shape: ${_interpreter.getInputShape()}");
      print("Model output shape: ${_interpreter.getOutputShape()}");

      // Load labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n');
      print("Labels loaded: ${_labels.length} labels");
    } catch (e) {
      print('Error loading model or labels: $e');
    }
  }

  Future<void> detectCurrency() async {
    if (isDetecting) return;
    
    if (showBoundingBoxes) {
      setState(() {
        showBoundingBoxes = false;
        currentRecognitions = [];
      });
      return;
    }

    setState(() {
      isDetecting = true;
    });

    try {
      print("Taking picture...");
      final image = await _controller.takePicture();
      print("Processing image: ${image.path}");

      // Load and preprocess image
      final imageData = File(image.path).readAsBytesSync();
      img.Image? decodedImage = img.decodeImage(imageData);
      if (decodedImage == null) {
        print("Failed to decode image");
        return;
      }

      // Resize image to match model input size (assuming 224x224)
      final processedImage = ImageProcessor()
          .add(ResizeOp(640, 640, ResizeMethod.BILINEAR))
          .add(NormalizeOp(127.5, 127.5))
          .process(TensorImage.fromImage(decodedImage));

      // Get input tensor shape
      final inputShape = _interpreter.getInputTensor(0).shape;
      final outputShape = _interpreter.getOutputTensor(0).shape;
      
      print("Input shape: $inputShape");
      print("Output shape: $outputShape");

      // Prepare input tensor
      TensorBuffer inputBuffer = TensorBuffer.createFixedSize(inputShape, TfLiteType.float32);
      inputBuffer.loadBuffer(processedImage.buffer);

      // Prepare output tensor
      TensorBuffer outputBuffer = TensorBuffer.createFixedSize(outputShape, TfLiteType.float32);

      // Run inference
      print("Running inference...");
      _interpreter.run(inputBuffer.buffer, outputBuffer.buffer);

      // Process results
      List<double> outputArray = outputBuffer.getDoubleList();
      print("Raw output: $outputArray");

      // Find detected classes (assuming output is probabilities for each class)
      List<Recognition> recognitions = [];
      for (int i = 0; i < outputArray.length; i++) {
        if (outputArray[i] > 0.5) { // Confidence threshold
          recognitions.add(
            Recognition(
              i.toString(),
              _labels[i],
              outputArray[i],
              null, // No bounding box for classification model
            ),
          );
        }
      }

      print("Recognitions: $recognitions");

      if (recognitions.isNotEmpty) {
        int sum = 0;
        String detectedNotes = "";

        for (var recognition in recognitions) {
          String label = recognition.label;
          print("Detected $label with confidence ${recognition.confidence}");
          
          int value = _getNoteValue(label);
          sum += value;
          detectedNotes += "$label, ";
        }

        setState(() {
          totalAmount = sum;
          showBoundingBoxes = true;
          currentRecognitions = recognitions;
        });

        await flutterTts.speak("Detected notes are $detectedNotes. Total amount is $sum rupees");
      } else {
        print("No currencies detected");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No currency detected')),
        );
      }
    } catch (e, stackTrace) {
      print("Error during detection: $e");
      print("Stack trace: $stackTrace");
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
    // Modify this according to your model's labels
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
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
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
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.blue,
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
                  ElevatedButton(
                    onPressed: isDetecting ? null : detectCurrency,
                    child: Text(
                      isDetecting 
                        ? 'Detecting...' 
                        : (showBoundingBoxes ? 'Tap to Continue' : 'Capture & Detect')
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
    _interpreter.close();
    _controller.dispose();
    super.dispose();
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> recognitions;

  BoundingBoxPainter(this.recognitions);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var recognition in recognitions) {
      if (recognition.containsKey('rect')) {
        final rect = recognition['rect'];
        canvas.drawRect(
          Rect.fromLTWH(
            rect['x'] * size.width,
            rect['y'] * size.height,
            rect['w'] * size.width,
            rect['h'] * size.height,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Add this class for storing recognitions
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