import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

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
  bool _isSpeaking = false;

  final FlutterTts _flutterTts = FlutterTts();

  final List<String> _imagePrompts = [
    "What is shown in this image?",
    "Describe the scene in detail.",
    "List all objects you can identify.",
    "What emotions are visible in the image?",
    "Is this image real or AI-generated?",
    "What is the setting or location?",
    "What is the person doing in this image?",
    "What time of day does this image represent?",
    "What style or art form is this image?",
    "Summarize this image in one sentence."
  ];

  final List<String> _audioPrompts = [
    "Transcribe the audio.",
    "Summarize what is being said.",
    "What is the speaker's emotion?",
    "Is this a conversation or a monologue?",
    "What language is being spoken?",
    "What is the background noise?",
    "Who might be speaking in this audio?",
    "Is this a song or a speech?",
    "What is the main topic of the audio?",
    "What is the tone of the speaker?",
    "Translate the audio to English."
  ];

  List<String> _currentPrompts = [];
  String? _selectedPrompt;

  @override
  void initState() {
    super.initState();
    _currentPrompts = _imagePrompts;

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setCancelHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

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
        _response = "";
      });
    }
  }

  Future<void> sendRequest() async {
    if (_file == null && _mode != "Audio Only") return;

    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
      _response = "";
    });

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
          await _speakResponse(); // auto-play response
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

  Future<void> _speakResponse() async {
    if (_response.isNotEmpty && !_isSpeaking) {
      setState(() {
        _isSpeaking = true;
      });

      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(_response);
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
              onChanged: (value) async {
                await _flutterTts.stop(); // stop any current speech
                setState(() {
                  _isSpeaking = false;
                  _response = ""; // clear response
                  _mode = value!;
                  _selectedPrompt = null;
                  _textController.clear();

                  if (_mode == "Text + Image") {
                    _currentPrompts = _imagePrompts;
                  } else if (_mode == "Text + Audio") {
                    _currentPrompts = _audioPrompts;
                  } else {
                    _currentPrompts = [];
                  }
                });
              },
            ),
            if (_mode != "Audio Only") ...[
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: "Enter prompt or choose suggestion",
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    onSelected: (value) {
                      setState(() {
                        _textController.text = value;
                        _selectedPrompt = value;
                      });
                    },
                    itemBuilder: (context) {
                      return _currentPrompts.map((prompt) {
                        return PopupMenuItem<String>(
                          value: prompt,
                          child: Text(prompt),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
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
              onPressed: _isLoading ? null : sendRequest,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Send to Gemini"),
            ),
            const SizedBox(height: 20),
                        const Text("Response:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(child: SingleChildScrollView(child: Text(_response))),
            if (_response.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ElevatedButton.icon(
                  onPressed: _isSpeaking ? null : _speakResponse,
                  icon: const Icon(Icons.volume_up),
                  label: Text(_isSpeaking ? "Speaking..." : "Play Response"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
