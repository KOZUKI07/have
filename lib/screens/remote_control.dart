import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class RoomControlPage extends StatefulWidget {
  final String backendURL;
  const RoomControlPage({super.key, required this.backendURL});

  @override
  State<RoomControlPage> createState() => _RoomControlPageState();
}

class _RoomControlPageState extends State<RoomControlPage> {
  Map<String, List<String>> rooms = {};
  String? selectedRoom;
  bool showRoomList = true;

  final Map<String, Map<String, String>> deviceCommands = {
    'LIGHT1': {'on': 'LIGHT1_ON', 'off': 'LIGHT1_OFF'},
    'FAN': {'on': 'FAN_ON', 'off': 'FAN_OFF'},
    'TV': {'on': 'TV_ON', 'off': 'TV_OFF'},
    'LIGHT2': {'on': 'LIGHT2_ON', 'off': 'LIGHT2_OFF'},
    'WASHER': {'on': 'WASHER_ON', 'off': 'WASHER_OFF'},
    'AC': {'on': 'AC_ON', 'off': 'AC_OFF'},
    'FRIDGE': {'on': 'FRIDGE_ON', 'off': 'FRIDGE_OFF'},
  };

  // Icons for devices [OFF icon, ON icon]
  final Map<String, List<IconData>> deviceIcons = {
    'LIGHT1': [Icons.lightbulb_outline, Icons.lightbulb],
    'FAN': [Icons.mode_fan_off_outlined, Icons.mode_fan_off],
    'TV': [Icons.tv_off, Icons.tv],
    'LIGHT2': [Icons.lightbulb_outline, Icons.lightbulb],
    'WASHER': [Icons.local_laundry_service_outlined, Icons.local_laundry_service],
    'AC': [Icons.ac_unit_outlined, Icons.ac_unit],
    'FRIDGE': [Icons.kitchen_outlined, Icons.kitchen],
  };

  Map<String, Map<String, bool>> deviceStates = {};

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  Future<void> loadRooms() async {
    final prefs = await SharedPreferences.getInstance();

    final rawRooms = prefs.getString('rooms') ?? '{}';
    final decodedRooms = jsonDecode(rawRooms) as Map<String, dynamic>;
    final loadedRooms = decodedRooms.map((k, v) => MapEntry(k, List<String>.from(v)));

    final savedRoom = prefs.getString('selectedRoom');

    final rawDeviceStates = prefs.getString('deviceStates') ?? '{}';
    final decodedDeviceStates = jsonDecode(rawDeviceStates) as Map<String, dynamic>;

    final Map<String, Map<String, bool>> loadedDeviceStates = {};
    decodedDeviceStates.forEach((room, devices) {
      loadedDeviceStates[room] = {};
      (devices as Map<String, dynamic>).forEach((device, state) {
        loadedDeviceStates[room]![device] = state as bool;
      });
    });

    // Initialize missing rooms/devices to false OFF state
    for (var room in loadedRooms.keys) {
      loadedDeviceStates.putIfAbsent(room, () => {
        for (var deviceKey in deviceCommands.keys) deviceKey: false,
      });

      for (var deviceKey in deviceCommands.keys) {
        loadedDeviceStates[room]!.putIfAbsent(deviceKey, () => false);
      }
    }

    setState(() {
      rooms = loadedRooms;
      deviceStates = loadedDeviceStates;
      if (savedRoom != null && rooms.containsKey(savedRoom)) {
        selectedRoom = savedRoom;
      }
    });
  }

  Future<void> saveDeviceStates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(deviceStates);
    await prefs.setString('deviceStates', jsonString);
  }

  Future<void> sendCommand(String cmd) async {
    if (selectedRoom == null || rooms[selectedRoom]!.isEmpty) return;

    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 50);
    }

    try {
      for (final espIp in rooms[selectedRoom]!) {
        await http.post(
          Uri.parse('${widget.backendURL}/send_command'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'command': cmd, 'esp_ip': espIp}),
        );
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('✅ Sent $cmd to $selectedRoom')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ Failed to send command: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive layout adjustments
    final screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.width > 600;
    
    // Responsive sizing parameters
    final double titleSize = isTablet ? 28.0 : 20.0;
    final double dropdownFontSize = isTablet ? 24.0 : 20.0;
    final double buttonFontSize = isTablet ? 20.0 : 16.0;
    final double iconSize = isTablet ? 32.0 : 24.0;
    final double gridSpacing = isTablet ? 24.0 : 16.0;
    final int gridColumns = isTablet ? 3 : 2;
    final EdgeInsets buttonPadding = isTablet 
        ? const EdgeInsets.symmetric(vertical: 20, horizontal: 16) 
        : const EdgeInsets.symmetric(vertical: 16);
    final double roomTitleSize = isTablet ? 32.0 : 24.0;
    final double appBarIconSize = isTablet ? 32.0 : 24.0;
    final double noRoomIconSize = isTablet ? 96.0 : 64.0;
    final double noRoomFontSize = isTablet ? 24.0 : 18.0;
    final EdgeInsets bodyPadding = EdgeInsets.all(isTablet ? 24 : 16);

    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            dropdownColor: Colors.tealAccent,
            value: selectedRoom,
            hint: Text(
              "SELECT ROOM",
              style: GoogleFonts.orbitron(
                fontSize: dropdownFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              
              ),
            ),
            icon: Icon(Icons.arrow_drop_down, 
                color: Colors.black, 
                size: appBarIconSize),
            items: rooms.keys
                .map(
                  (room) => DropdownMenuItem<String>(
                    value: room,
                    child: Text(
                      room,
                      style: GoogleFonts.orbitron(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              setState(() {
                selectedRoom = value;
              });
              final prefs = await SharedPreferences.getInstance();
              if (value != null) {
                await prefs.setString('selectedRoom', value);
              }
            },
          ),
        ),
        backgroundColor: Colors.tealAccent,
        iconTheme: IconThemeData(color: Colors.black, size: appBarIconSize),
        centerTitle: true,
      ),
      body: Padding(
        padding: bodyPadding,
        child: rooms.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.meeting_room, 
                        size: noRoomIconSize, 
                        color: Colors.white30),
                    SizedBox(height: isTablet ? 32 : 16),
                    Text(
                      'No rooms found.\n\nAdd a New Room in Settings Page',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54, 
                        fontSize: noRoomFontSize
                      ),
                    ),
                  ],
                ),
              )
            : _buildRemoteControl(
                isTablet: isTablet,
                gridColumns: gridColumns,
                gridSpacing: gridSpacing,
                buttonFontSize: buttonFontSize,
                iconSize: iconSize,
                buttonPadding: buttonPadding,
                roomTitleSize: roomTitleSize,
              ),
      ),
    );
  }

  Widget _buildRemoteControl({
    required bool isTablet,
    required int gridColumns,
    required double gridSpacing,
    required double buttonFontSize,
    required double iconSize,
    required EdgeInsets buttonPadding,
    required double roomTitleSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: isTablet ? 16 : 4),
        if (selectedRoom == null)
          Center(
            child: Text(
              'Please select a room to control devices.',
              style: TextStyle(
                color: Colors.white54, 
                fontSize: isTablet ? 22 : 16
              ),
            ),
          )
        else ...[
          Center(
            child: Text(
              '${selectedRoom!} REMOTE',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: roomTitleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: isTablet ? 32 : 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: gridColumns,
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: gridSpacing,
              childAspectRatio: isTablet ? 1.5 : 1.8,
              children: deviceCommands.keys
                  .map((deviceKey) => buildToggleButton(
                    deviceKey, 
                    buttonFontSize, 
                    iconSize, 
                    buttonPadding,
                  ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget buildToggleButton(
    String deviceKey, 
    double fontSize, 
    double iconSize,
    EdgeInsets padding,
  ) {
    if (selectedRoom == null) return const SizedBox();

    bool isOn = deviceStates[selectedRoom]?[deviceKey] ?? false;

    String label = isOn ? '$deviceKey OFF' : '$deviceKey ON';
    String command = isOn
        ? deviceCommands[deviceKey]!['off']!
        : deviceCommands[deviceKey]!['on']!;

    IconData icon = isOn
        ? (deviceIcons[deviceKey] != null 
            ? deviceIcons[deviceKey]![1] 
            : Icons.power)
        : (deviceIcons[deviceKey] != null 
            ? deviceIcons[deviceKey]![0] 
            : Icons.power);

    return ElevatedButton.icon(
      onPressed: () async {
        await sendCommand(command);
        setState(() {
          deviceStates[selectedRoom]![deviceKey] = !isOn;
        });
        await saveDeviceStates();
      },
      icon: Icon(
        icon,
        color: isOn ? Colors.red : Colors.green,
        size: iconSize,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.tealAccent,
        shape: const StadiumBorder(),
        padding: padding,
      ),
    );
  }
}