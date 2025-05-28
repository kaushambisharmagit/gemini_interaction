import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() => runApp(GeminiApp());

class GeminiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Interaction',
      home: GeminiInteraction(),
    );
  }
}

class GeminiInteraction extends StatefulWidget {
  @override
  _GeminiInteractionState createState() => _GeminiInteractionState();
}

class _GeminiInteractionState extends State<GeminiInteraction> {
  File? _file;
  String _response = "";
  final TextEditingController _textController = TextEditingController();
  String _mode = "Text + Image";

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: _mode == "Text + Image" ? FileType.image : FileType.audio,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
      });
    }
  }

  Future<void> captureImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _file = File(pickedFile.path);
      });
    }
  }

  Future<void> recordAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
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

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      setState(() {
        _response = json.decode(responseBody)['response'] ?? "No response";
      });
    } catch (e) {
      setState(() {
        _response = "Request failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gemini Interaction")),
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
                decoration: InputDecoration(labelText: "Enter text"),
              ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: pickFile,
              child: Text(_mode == "Text + Image" ? "Pick Image" : "Pick Audio"),
            ),
            if (_mode == "Text + Image")
              ElevatedButton(
                onPressed: captureImage,
                child: Text("Capture Image"),
              ),
            if (_mode != "Text + Image")
              ElevatedButton(
                onPressed: recordAudio,
                child: Text("Record Audio"),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendRequest,
              child: Text("Send to Gemini"),
            ),
            SizedBox(height: 20),
            Text("Response:", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(child: SingleChildScrollView(child: Text(_response))),
          ],
        ),
      ),
    );
  }
}
