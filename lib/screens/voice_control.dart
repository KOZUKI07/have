import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class VoiceControlPage extends StatefulWidget {
  final String backendURL;
  const VoiceControlPage({super.key, required this.backendURL});

  @override
  State<VoiceControlPage> createState() => _VoiceControlPageState();
}

class _VoiceControlPageState extends State<VoiceControlPage> {
  bool _isListening = false;
  String _spokenText = "";

  List<String> cameraIDs = [];
  String? selectedCam;

  Process? _recognitionProcess;
  Process? _ttsProcess;
  Timer? _listeningTimer;
  bool _audioError = false;

  @override
  void initState() {
    super.initState();
    _loadCameraIDs();
    _testAudioInput();
  }

  // In _testAudioInput()
  Future<void> _testAudioInput() async {
    try {
      final result = await Process.run('arecord', [
        '--device',
        'default',
        '-d',
        '1',
        '--format=S16_LE',
        '--rate=16000',
        '--file-type=raw',
        '/dev/null',
      ]);
      if (result.exitCode != 0) {
        setState(() => _audioError = true);
        print('Microphone test failed: ${result.stderr}');
      } else {
        setState(() => _audioError = false); // Reset error state on success
      }
    } catch (e) {
      setState(() => _audioError = true);
      print('Audio test error: $e');
    }
  }

  Future<void> _loadCameraIDs() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('cameraIDs') ?? [];
    setState(() {
      cameraIDs = ids;
      if (ids.isNotEmpty) selectedCam = ids.first;
    });
  }

  Future<void> _sendCommand(String cmd) async {
    if (cameraIDs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No camera devices found')));
      return;
    }

    bool allSuccess = true;

    for (String camId in cameraIDs) {
      try {
        final response = await http.post(
          Uri.parse('${widget.backendURL}/send_command'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'camera_id': camId, 'command': cmd}),
        );

        if (response.statusCode != 200) {
          allSuccess = false;
          print('Error sending command to $camId: ${response.statusCode}');
        }
      } catch (e) {
        allSuccess = false;
        print('Network error sending command to $camId: $e');
      }
    }

    if (allSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Command sent to all devices successfully'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Command sent with some errors')),
      );
    }
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> dp = List.generate(
      s1.length + 1,
      (_) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      for (int j = 0; j <= s2.length; j++) {
        if (i == 0) {
          dp[i][j] = j;
        } else if (j == 0) {
          dp[i][j] = i;
        } else if (s1[i - 1] == s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] =
              1 +
              [
                dp[i - 1][j],
                dp[i][j - 1],
                dp[i - 1][j - 1],
              ].reduce((a, b) => a < b ? a : b);
        }
      }
    }
    return dp[s1.length][s2.length];
  }

  double _similarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 100.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    int distance = _levenshteinDistance(s1, s2);
    int maxLength = s1.length > s2.length ? s1.length : s2.length;
    return (1.0 - distance / maxLength) * 100;
  }

  void _processVoiceCommand(String text) async {
    print('Original text: $text');

    String processedText = text
        .toLowerCase()
        .replaceAll(
          RegExp(r'\b(a|the|please|can you|could you|would you|all)\b'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAllMapped(RegExp(r'\b(won|one)\b'), (_) => '1')
        .replaceAllMapped(RegExp(r'\b(to|too|two)\b'), (_) => '2')
        .replaceAllMapped(RegExp(r'\b(three|tree)\b'), (_) => '3');

    processedText = processedText
        .replaceAllMapped(RegExp(r'\blights?\b'), (m) => 'light')
        .replaceAll('lite', 'light')
        .replaceAllMapped(RegExp(r'\b(fun|van)\b'), (m) => 'fan')
        .replaceAll(' of ', ' off ')
        .replaceAll('air conditioner', 'ac')
        .replaceAll('refrigerator', 'fridge')
        .replaceAll('air conditioning', 'ac')
        .replaceAll('tele vision', 'tv')
        .replaceAll('washing machine', 'washer');

    processedText =
        processedText
            .replaceAllMapped(
              RegExp(
                r'\b(turn)?\s*(on|off)\s*(?:the)?\s*(light|fan)\s*(\d*)\b',
              ),
              (m) =>
                  'turn ${m[2]} ${m[3]}${m[4]?.isNotEmpty == true ? " ${m[4]}" : ""}'
                      .trim(),
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    print('Processed text: $processedText');

    final lightNumberRegExp = RegExp(r'light (\d+)');
    final lightMatch = lightNumberRegExp.firstMatch(processedText);
    if (lightMatch != null) {
      final lightNumber = int.tryParse(lightMatch.group(1)!);
      if (lightNumber == null || lightNumber < 1 || lightNumber > 3) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No such light')));
        await _speak("Sorry, no such light");
        return;
      }
    }

    final commandPatterns = [
      RegExp(
        r'\b(turn|switch|put|set)\s+(on|off)\s+(?:the\s+)?(light|fan|tv|ac|washer|fridge)(?:\s+(\d+))?\b',
      ),
      RegExp(r'\b(light|fan|tv|ac|washer|fridge)(?:\s+(\d+))?\s+(on|off)\b'),
      RegExp(r'\b(light|fan|tv|ac|washer|fridge)\s+(on|off)\b'),
      RegExp(r'\b(turn|switch)\s+(on|off)\s+(\d+)\s+(light|fan)\b'),
    ];

    bool restructured = false;
    for (var pattern in commandPatterns) {
      if (pattern.hasMatch(processedText)) {
        processedText = processedText.replaceAllMapped(pattern, (match) {
          restructured = true;
          if (pattern == commandPatterns[0] || pattern == commandPatterns[3]) {
            return 'turn ${match[2]} ${match[3]}${match[4] != null ? " ${match[4]}" : ""}';
          } else {
            return 'turn ${match[3] ?? match[2]} ${match[1]}${match[2] != null && match[2]!.isNotEmpty && int.tryParse(match[2]!) != null ? " ${match[2]}" : ""}';
          }
        });
        if (restructured) break;
      }
    }

    processedText = processedText
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAllMapped(
          RegExp(r'\b(light|fan) (on|off) (on|off)\b'),
          (_) => '',
        );

    print('Processed text: $processedText');

    if (!processedText.contains(
      RegExp(r'\b(light|fan|ac|fridge|washer|tv)\b'),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Invalid command format',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Please use commands like:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              const Text('• "Turn on light 1"'),
              const Text('• "Turn off fan"'),
              const Text('• "Light 2 on"'),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      await _speak("Sorry, I didn't understand. Please try again");
      return;
    }
    if (processedText.isEmpty) {
      await _speak("No command detected");
      return;
    }
    final commandMap = {
      'turn on light 1': 'LIGHT1_ON',
      'turn on light 2': 'LIGHT2_ON',
      'turn on light 3': 'LIGHT3_ON',
      'turn off light 1': 'LIGHT1_OFF',
      'turn off light 2': 'LIGHT2_OFF',
      'turn off light 3': 'LIGHT3_OFF',
      'turn on fan': 'FAN_ON',
      'turn off fan': 'FAN_OFF',
      'light 1 on': 'LIGHT1_ON',
      'light 2 on': 'LIGHT2_ON',
      'light 3 on': 'LIGHT3_ON',
      'light 1 off': 'LIGHT1_OFF',
      'light 2 off': 'LIGHT2_OFF',
      'light 3 off': 'LIGHT3_OFF',
      'turn on tv': 'TV_ON',
      'turn off tv': 'TV_OFF',
      'tv on': 'TV_ON',
      'tv off': 'TV_OFF',
      'turn on ac': 'AC_ON',
      'turn off ac': 'AC_OFF',
      'ac on': 'AC_ON',
      'ac off': 'AC_OFF',
      'turn on washer': 'WASHER_ON',
      'turn off washer': 'WASHER_OFF',
      'washer on': 'WASHER_ON',
      'washer off': 'WASHER_OFF',
      'turn on fridge': 'FRIDGE_ON',
      'turn off fridge': 'FRIDGE_OFF',
      'fridge on': 'FRIDGE_ON',
      'fridge off': 'FRIDGE_OFF',
    };

    String? bestMatchCommand;
    double highestSimilarity = 0;

    for (var entry in commandMap.entries) {
      double similarity = _similarity(processedText, entry.key);
      if (similarity > highestSimilarity) {
        highestSimilarity = similarity;
        bestMatchCommand = entry.value;
      }
    }

    print('Best match: $bestMatchCommand ($highestSimilarity%)');

    if (highestSimilarity >= 75 && bestMatchCommand != null) {
      String action = "Turning ";
      if (bestMatchCommand.endsWith('_ON')) {
        action += "on ";
      } else if (bestMatchCommand.endsWith('_OFF')) {
        action += "off ";
      }

      String device = "";
      if (bestMatchCommand.contains('LIGHT')) {
        device = "light ${bestMatchCommand.split('_')[0].substring(5)}";
      } else if (bestMatchCommand.contains('FAN')) {
        device = "fan";
      } else if (bestMatchCommand.contains('TV')) {
        device = "TV";
      } else if (bestMatchCommand.contains('AC')) {
        device = "AC";
      } else if (bestMatchCommand.contains('WASHER')) {
        device = "washer";
      } else if (bestMatchCommand.contains('FRIDGE')) {
        device = "fridge";
      }

      await _speak(action + device);
      _sendCommand(bestMatchCommand);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sorry, couldn't understand. Please try again."),
        ),
      );
      await _speak("Sorry, I couldn't get that. Try again");
    }

    setState(() => _spokenText = "");
  }

  Future<void> _speak(String text) async {
    try {
      if (_ttsProcess != null) {
        _ttsProcess!.kill();
        _ttsProcess = null;
      }
      _ttsProcess = await Process.start('espeak', ['-ven+f3', text]);
    } catch (e) {
      print('TTS error: $e');
    }
  }

  Future<void> _listenVoiceCommand() async {
    if (_audioError) {
      await _speak("Microphone error. Please check audio settings.");
      return;
    }

    setState(() {
      _isListening = true;
      _spokenText = "Listening...";
    });

    try {
      await _stopListening();

      // In _listenVoiceCommand()
      _recognitionProcess = await Process.start('pocketsphinx_continuous', [
        '-inmic',
        'yes',
        '-adcdev', 'default', // Explicitly specify device
        '-logfn', '/dev/null',
        '-kws_threshold', '1e-5', // More reasonable threshold
        '-hmm', '/usr/share/pocketsphinx/model/en-us/en-us', // Specify model
        '-dict',
        '/usr/share/pocketsphinx/model/en-us/cmudict-en-us.dict', // Dictionary
      ]);

      // Capture exit code
      _recognitionProcess!.exitCode.then((code) {
        print('PocketSphinx exited with code: $code');
        if (code != 0 && !_isListening) {
          setState(() => _audioError = true);
        }
      });

      // Handle errors
      _recognitionProcess!.stderr.transform(utf8.decoder).listen((data) {
        print('PocketSphinx stderr: $data');
        if (data.contains('Failed to open audio device') ||
            data.contains('No such entity')) {
          setState(() => _audioError = true);
        }
      });

      // Process output
      _recognitionProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            print('PocketSphinx: $line');
            if (line.contains('detected')) {
              final startIndex = line.indexOf('detected') + 9;
              setState(() => _spokenText = line.substring(startIndex).trim());
            } else if (line.contains(':')) {
              final parts = line.split(':');
              if (parts.length > 1) {
                setState(() => _spokenText = parts[1].trim());
              }
            }
          });

      // Set timeout
      _listeningTimer = Timer(const Duration(seconds: 15), () async {
        await _stopListening();
        if (_spokenText.isNotEmpty &&
            _spokenText != "Listening..." &&
            !_audioError) {
          _processVoiceCommand(_spokenText);
        } else if (_audioError) {
          await _speak("Audio device error. Please check microphone");
        }
        setState(() => _spokenText = "");
      });
    } catch (e) {
      print('Recognition error: $e');
      setState(() => _audioError = true);
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    _listeningTimer?.cancel();

    if (_recognitionProcess != null) {
      try {
        _recognitionProcess!.kill(ProcessSignal.sigterm);
        await _recognitionProcess!.exitCode.timeout(
          const Duration(seconds: 1),
          onTimeout: () => -1,
        );
      } catch (e) {
        print('Error stopping process: $e');
      } finally {
        _recognitionProcess = null;
      }
    }
  }

  @override
  void dispose() {
    _stopListening();
    _ttsProcess?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isLargeScreen = screenSize.width > 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'VOICE CONTROL (Linux)',
          style: GoogleFonts.orbitron(
            fontSize: isLargeScreen ? 28 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.tealAccent,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        elevation: 10,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isLargeScreen ? 40 : 16,
          horizontal: isLargeScreen ? 30 : 16,
        ),
        child:
            cameraIDs.isEmpty
                ? Center(
                  child: Text(
                    'No Device configured',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isLargeScreen ? 24 : 16,
                    ),
                  ),
                )
                : Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLargeScreen) const SizedBox(height: 30),
                      Center(
                        child: Text(
                          'Tap to speak command',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: isLargeScreen ? 26 : 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: isLargeScreen ? 70 : 55),
                      Center(
                        child: GestureDetector(
                          onTap:
                              _isListening
                                  ? _stopListening
                                  : _listenVoiceCommand,
                          child: AnimatedScale(
                            scale: _isListening ? 1.5 : 1.0,
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOut,
                            child: Container(
                              width: isLargeScreen ? 180 : 120,
                              height: isLargeScreen ? 180 : 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    _audioError
                                        ? Colors.orange
                                        : (_isListening
                                            ? Colors.greenAccent
                                            : Colors.tealAccent),
                                boxShadow:
                                    _isListening
                                        ? [
                                          BoxShadow(
                                            color: (_audioError
                                                    ? Colors.orange
                                                    : Colors.greenAccent)
                                                .withOpacity(0.6),
                                            spreadRadius:
                                                isLargeScreen ? 15 : 10,
                                            blurRadius: isLargeScreen ? 30 : 20,
                                          ),
                                        ]
                                        : [],
                              ),
                              child:
                                  _audioError
                                      ? const Icon(
                                        Icons.warning,
                                        size: 50,
                                        color: Colors.black,
                                      )
                                      : const Icon(
                                        Icons.mic,
                                        size: 50,
                                        color: Colors.black,
                                      ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isLargeScreen ? 70 : 55),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _spokenText.isEmpty
                                ? (_audioError
                                    ? "Audio device error!"
                                    : "Say a command...")
                                : _spokenText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _audioError ? Colors.orange : Colors.white,
                              fontSize: isLargeScreen ? 26 : 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isLargeScreen)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 30),
                            child: Column(
                              children: [
                                Text(
                                  'Supported commands: light, fan, TV, AC, washer, fridge',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 20,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_audioError)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[900],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            "Audio Configuration Required",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            "1. Install required packages:",
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SelectableText(
                                            "sudo apt-get install pocketsphinx pocketsphinx-en-us",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            "2. Test microphone:",
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SelectableText(
                                            "arecord -l",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton(
                                            onPressed: _testAudioInput,
                                            child: const Text(
                                              "Retry Detection",
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (isLargeScreen)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Using PocketSphinx & eSpeak',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }
}
