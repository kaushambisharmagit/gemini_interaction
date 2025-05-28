import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const GeminiApp());

class GeminiApp extends StatelessWidget {
  const GeminiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Interaction',
      home: const GeminiInteraction(),
    );
  }
}

class GeminiInteraction extends StatefulWidget {
  const GeminiInteraction({Key? key}) : super(key: key);

  @override
  _GeminiInteractionState createState() => _GeminiInteractionState();
}

class _GeminiInteractionState extends State<GeminiInteraction> {
  File? _file;
  String _response = "";
  final TextEditingController _textController = TextEditingController();
  String _mode = "Text + Image";
  bool _isLoading = false;
  String? _fileName;

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: _mode == "Text + Image" ? FileType.image : FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final extension = file.path.split('.').last.toLowerCase();

      final allowedImageExts = ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'];
      final allowedAudioExts = ['wav', 'mp3', 'm4a', 'ogg'];

      final isValid = _mode == "Text + Image"
          ? allowedImageExts.contains(extension)
          : allowedAudioExts.contains(extension);

      if (!isValid) {
        setState(() {
          _response = "Unsupported file format: .$extension";
        });
        return;
      }

      setState(() {
        _file = file;
        _fileName = file.path.split('/').last;
        _response = ""; // Clear previous response
      });
    }
  }

  Future<void> sendRequest() async {
    if (_file == null && _mode != "Audio Only") return;

    if (kIsWeb) {
      setState(() {
        _response = "File upload is not supported on web.";
      });
      return;
    }

    Uri uri;
    if (_mode == "Text + Image") {
      uri = Uri.parse("https://gemini-interaction.onrender.com/text-image");
    } else if (_mode == "Text + Audio") {
      uri = Uri.parse("https://gemini-interaction.onrender.com/text-audio");
    } else {
      uri = Uri.parse("https://gemini-interaction.onrender.com/audio-only");
    }

    final request = http.MultipartRequest('POST', uri);
    if (_mode != "Audio Only") {
      request.fields['text'] = _textController.text;
    }

    if (_file != null) {
      try {
        request.files.add(await http.MultipartFile.fromPath(
          _mode == "Text + Image" ? 'image' : 'audio',
          _file!.path,
        ));
      } catch (e) {
        setState(() {
          _response = "Failed to attach file: $e";
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        try {
          final decoded = json.decode(responseBody);
          setState(() {
            _response = decoded['response'] ?? "No response field in JSON.";
          });
        } catch (e) {
          setState(() {
            _response = "Invalid JSON response: $responseBody";
          });
        }
      } else {
        setState(() {
          _response = "Server error ${response.statusCode}: $responseBody";
        });
      }
    } catch (e) {
      setState(() {
        _response = "Request failed: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gemini Interaction")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _mode,
              items: ["Text + Image", "Text + Audio", "Audio Only"]
                  .map((mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _mode = value!),
            ),
            if (_mode != "Audio Only")
              TextField(
                controller: _textController,
                decoration: const InputDecoration(labelText: "Enter text"),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: pickFile,
              child: Text(_mode == "Text + Image" ? "Pick Image" : "Pick Audio"),
            ),
            if (_fileName != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text("Selected file: $_fileName"),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendRequest,
              child: _isLoading ? const CircularProgressIndicator() : const Text("Send to Gemini"),
            ),
            const SizedBox(height: 20),
            const Text("Response:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(child: SingleChildScrollView(child: Text(_response))),
          ],
        ),
      ),
    );
  }
}
