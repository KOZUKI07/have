import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final String currentIP;
  final Function(String) onSave;
  final Function(String)? onDelete;
  const SettingsPage({
    super.key,
    required this.currentIP,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController ipController;

  List<String> cameraIDs = [];
  Map<String, String> cameraIPs = {};
  Map<String, List<String>> espIPs = {};

  @override
  void initState() {
    super.initState();
    ipController = TextEditingController(text: widget.currentIP);
    loadCameraSettings();
    loadRooms();
  }

  Future<void> loadCameraSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('cameraIDs') ?? [];
    final cams = jsonDecode(prefs.getString('cameraIPs') ?? '{}');
    final esps = jsonDecode(prefs.getString('espIPs') ?? '{}');

    setState(() {
      cameraIDs = ids;
      cameraIPs = Map<String, String>.from(cams);
      espIPs = {};
      (esps as Map<String, dynamic>).forEach((key, value) {
        espIPs[key] = List<String>.from(value);
      });
    });
  }

  Future<void> saveCameraSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cameraIDs', cameraIDs);
    await prefs.setString('cameraIPs', jsonEncode(cameraIPs));
    await prefs.setString(
      'espIPs',
      jsonEncode(espIPs.map((k, v) => MapEntry(k, v.toList()))),
    );
  }

  Future<void> deleteCamera(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Confirm Delete",
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 20,
          ),
        ),
        content: Text(
          "Are you sure you want to remove camera \"$id\"?",
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600 ? 20 : 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600 ? 20 : 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete",
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600 ? 20 : 16,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 🔁 Tell backend to stop thread
      final backend = 'http://${widget.currentIP}';
      await http.post(
        Uri.parse("$backend/delete_camera"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"camera_id": id}),
      );

      setState(() {
        cameraIDs.remove(id);
        cameraIPs.remove(id);
        espIPs.remove(id);
      });

      await saveCameraSettings();
      if (widget.onDelete != null) {
        widget.onDelete!(id);
      }
    }
  }

  Map<String, List<String>> rooms = {};
  String? selectedRoom;
  bool showRoomList = true;

  final Map<String, String> commandLabels = {
    'LIGHT1_ON': 'LIGHT 1 ON',
    'LIGHT1_OFF': 'LIGHT 1 OFF',
    'FAN_ON': 'FAN ON',
    'FAN_OFF': 'FAN OFF',
    'TV_ON': 'TV ON',
    'TV_OFF': 'TV OFF',
    'LIGHT2_ON': 'LIGHT 2 ON',
    'LIGHT2_OFF': 'LIGHT 2 OFF',
    'HEATER_OFF': 'WASHING ON',
    'HEATER_ON': 'WASHING OFF',
    'AC_OFF': 'AC ON',
    'AC_ON': 'AC OFF',
    'FRIDGE_OFF': 'FRIDGE ON',
    'FRIDGE_ON': 'FRIDGE OFF',
  };

  Future<void> loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('rooms') ?? '{}';
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    setState(() {
      rooms = decoded.map((k, v) => MapEntry(k, List<String>.from(v)));
    });
  }

  Future<void> saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rooms', jsonEncode(rooms));
  }

  void addRoomDialog() {
    String roomName = '';
    String espInput = '';

    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final titleFontSize = isLargeScreen ? 24.0 : 20.0;
    final contentFontSize = isLargeScreen ? 20.0 : 16.0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          "Add Room",
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: titleFontSize,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (v) => roomName = v.trim(),
              style: TextStyle(
                color: Colors.white70,
                fontSize: contentFontSize,
              ),
              decoration: InputDecoration(
                labelText: 'Room name',
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: contentFontSize,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
              ),
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            TextField(
              onChanged: (v) => espInput = v.trim(),
              style: TextStyle(
                color: Colors.white70,
                fontSize: contentFontSize,
              ),
              decoration: InputDecoration(
                labelText: 'ESP IP(s) (comma-separated)',
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: contentFontSize,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (roomName.isNotEmpty && !rooms.containsKey(roomName)) {
                final espList = espInput
                    .split(',')
                    .map((e) => e.trim())
                    .where((ip) => ip.isNotEmpty)
                    .toList();

                setState(() {
                  rooms[roomName] = espList;
                });
                saveRooms();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 32 : 24,
                vertical: isLargeScreen ? 16 : 12,
              ),
            ),
            child: Text(
              "Add",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: contentFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void deleteRoom(String name) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final fontSize = isLargeScreen ? 20.0 : 16.0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Delete Room',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: fontSize * 1.2,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$name"?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: fontSize,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                rooms.remove(name);
                if (selectedRoom == name) {
                  selectedRoom = null;
                  showRoomList = true;
                }
              });
              saveRooms();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final titleFontSize = isLargeScreen ? 24.0 : 20.0;
    final contentFontSize = isLargeScreen ? 20.0 : 16.0;
    final cardPadding = isLargeScreen ? 24.0 : 16.0;
    final gridCrossAxisCount = isLargeScreen ? 2 : 1;
    final gridChildAspectRatio = isLargeScreen ? 1.0 : 1.2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "SETTINGS",
          style: GoogleFonts.orbitron(
            fontSize: titleFontSize * 1.2,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.tealAccent,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Configured Cameras & ESP",
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent,
              ),
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            if (cameraIDs.isNotEmpty)
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: gridCrossAxisCount,
                crossAxisSpacing: isLargeScreen ? 24 : 16,
                mainAxisSpacing: isLargeScreen ? 24 : 16,
                childAspectRatio: gridChildAspectRatio,
                children: cameraIDs.map((id) {
                  final espList = espIPs[id] ?? [];
                  return _buildCameraCard(
                    id: id,
                    espList: espList,
                    fontSize: contentFontSize,
                    padding: cardPadding,
                  );
                }).toList(),
              ),
            if (cameraIDs.isEmpty)
              Center(
                child: Text(
                  "No cameras configured",
                  style: TextStyle(
                    fontSize: contentFontSize,
                    color: Colors.white70,
                  ),
                ),
              ),
            SizedBox(height: isLargeScreen ? 32 : 24),
            Text(
              'MANUAL REMOTE CONFIG',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent,
              ),
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            _buildAddRoomCard(
              fontSize: contentFontSize,
              padding: cardPadding,
              isLargeScreen: isLargeScreen,
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            if (rooms.isNotEmpty)
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: gridCrossAxisCount,
                crossAxisSpacing: isLargeScreen ? 24 : 16,
                mainAxisSpacing: isLargeScreen ? 24 : 16,
                childAspectRatio: gridChildAspectRatio,
                children: rooms.entries.map((entry) {
                  final roomName = entry.key;
                  final espList = entry.value;
                  return _buildRoomCard(
                    roomName: roomName,
                    espList: espList,
                    fontSize: contentFontSize,
                    padding: cardPadding,
                  );
                }).toList(),
              ),
            if (rooms.isEmpty)
              Center(
                child: Text(
                  "No rooms configured",
                  style: TextStyle(
                    fontSize: contentFontSize,
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard({
    required String id,
    required List<String> espList,
    required double fontSize,
    required double padding,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 6,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📸  Camera ID: $id",
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: padding / 2),
            Text(
              "📷  Camera IP: ${cameraIPs[id]}",
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
              ),
            ),
            SizedBox(height: padding / 2),
            Text(
              "📡  ESP IPs:",
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
              ),
            ),
            ...espList.map(
              (ip) => Padding(
                padding: EdgeInsets.only(left: padding, top: padding / 4),
                child: Text(
                  "• $ip",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: fontSize * 0.9,
                  ),
                ),
              ),
            ),
            if (espList.isEmpty)
              Padding(
                padding: EdgeInsets.only(left: padding, top: padding / 4),
                child: Text(
                  "Not set",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: fontSize * 0.9,
                  ),
                ),
              ),
            Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon: Icon(
                  Icons.remove_circle,
                  color: Colors.tealAccent,
                  size: fontSize * 1.8,
                ),
                onPressed: () => deleteCamera(id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard({
    required String roomName,
    required List<String> espList,
    required double fontSize,
    required double padding,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 6,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🏠 Room: $roomName",
              style: TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
            SizedBox(height: padding / 2),
            Text(
              "🔌 ESP IPs:",
              style: TextStyle(
                color: Colors.white70,
                fontSize: fontSize,
              ),
            ),
            ...espList.map(
              (ip) => Padding(
                padding: EdgeInsets.only(left: padding, top: padding / 4),
                child: Text(
                  "• $ip",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize * 0.9,
                  ),
                ),
              ),
            ),
            Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon: Icon(
                  Icons.remove_circle,
                  color: Colors.tealAccent,
                  size: fontSize * 1.8,
                ),
                onPressed: () => deleteRoom(roomName),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRoomCard({
    required double fontSize,
    required double padding,
    required bool isLargeScreen,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 6,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          children: [
            Text(
              'ADD ROOM WITH ESP',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
              ),
            ),
            Spacer(),
            IconButton(
              onPressed: addRoomDialog,
              icon: Icon(
                Icons.add_circle,
                color: Colors.tealAccent,
                size: fontSize * 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}