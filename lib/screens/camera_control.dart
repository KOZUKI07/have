import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hand_gesture_app/screens/settings.dart';

class CameraControlPage extends StatefulWidget {
  const CameraControlPage({super.key});

  @override
  _CameraControlPageState createState() => _CameraControlPageState();
}

class _CameraControlPageState extends State<CameraControlPage> {
  String backendURL = "http://192.168.137.1:8001";
  final cameraIDController = TextEditingController();
  final cameraIPController = TextEditingController();
  final espIPController = TextEditingController();

  final Map<String, String> cameraIPs = {};
  final Map<String, List<String>> espIPs = {};
  final Map<String, Map<String, String>> gestureData = {};
  final Map<String, bool> detectionEnabled = {};

  List<String> cameraIDs = [];
  Timer? gestureTimer;

  @override
  void initState() {
    super.initState();
    loadCameraConfigurations();
    gestureTimer = Timer.periodic(Duration(seconds: 1), (_) {
      for (var id in cameraIDs) {
        if (detectionEnabled[id] ?? false) {
          fetchCurrentGesture(id);
          fetchClassifiedGesture(id);
        }
      }
    });
  }

  Future<void> loadCameraConfigurations() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('cameraIDs') ?? [];
    final cams = prefs.getString('cameraIPs') ?? '{}';
    final esps = prefs.getString('espIPs') ?? '{}';
    final toggles = prefs.getString('detectionEnabled') ?? '{}';

    setState(() {
      cameraIDs = ids;
      cameraIPs.addAll(Map<String, String>.from(jsonDecode(cams)));
      final decodedESPs = Map<String, dynamic>.from(jsonDecode(esps));
      decodedESPs.forEach((key, value) {
        espIPs[key] = List<String>.from(value);
      });
      detectionEnabled.addAll(Map<String, bool>.from(jsonDecode(toggles)));
    });
  }

  Future<void> saveConfigurations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cameraIDs', cameraIDs);
    await prefs.setString('cameraIPs', jsonEncode(cameraIPs));
    await prefs.setString(
      'espIPs',
      jsonEncode(espIPs.map((k, v) => MapEntry(k, v.toList()))),
    );
    await prefs.setString('detectionEnabled', jsonEncode(detectionEnabled));
  }

  Future<void> updateCameraIP() async {
    final cameraID = cameraIDController.text.trim();
    final ip = cameraIPController.text.trim();
    if (cameraID.isEmpty || ip.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse("$backendURL/update_camera_ip"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"camera_id": cameraID, "camera_ip": ip}),
      );

      if (response.statusCode == 200) {
        setState(() {
          if (!cameraIDs.contains(cameraID)) {
            cameraIDs.add(cameraID);
            detectionEnabled[cameraID] = true;
          }
          cameraIPs[cameraID] = ip;
        });
        await saveConfigurations();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("📷 Camera IP set for $cameraID")),
        );
      } else {
        throw Exception('Failed to update camera IP');
      }
    } catch (e) {
      print("❌ Error updating camera IP: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to set Camera IP!")));
    }
  }

  Future<void> updateEspIP() async {
    final cameraID = cameraIDController.text.trim();
    final ip = espIPController.text.trim();
    if (cameraID.isEmpty || ip.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse("$backendURL/update_esp_ip"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"camera_id": cameraID, "esp_ip": ip}),
      );

      if (response.statusCode == 200) {
        setState(() {
          espIPs.putIfAbsent(cameraID, () => []);
          if (!espIPs[cameraID]!.contains(ip)) {
            espIPs[cameraID]!.add(ip);
          }
        });
        await saveConfigurations();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("📡 ESP IP added for $cameraID")),
        );
      } else {
        throw Exception('Failed to update ESP IP');
      }
    } catch (e) {
      print("❌ Error updating ESP IP: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to set ESP IP!")));
    }
  }

  Future<void> fetchCurrentGesture(String cameraID) async {
    try {
      final response = await http.get(
        Uri.parse("$backendURL/current-gesture?camera_id=$cameraID"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawTimestamp = data['timestamp'] ?? "";
        String formattedTime = "N/A";
        try {
          final parsed = DateTime.parse(rawTimestamp);
          formattedTime = DateFormat('d MMM y, hh:mm:ss a').format(parsed);
        } catch (_) {
          formattedTime = rawTimestamp;
        }

        setState(() {
          gestureData[cameraID] = {
            "gesture": data['gesture'] ?? "None",
            "fingerPattern": (data['finger_pattern'] ?? []).toString(),
            "timestamp": formattedTime,
          };
        });
      }
    } catch (e) {
      print("❌ Error fetching gesture for $cameraID: $e");
    }
  }

  Future<void> fetchClassifiedGesture(String cameraID) async {
    try {
      final response = await http.get(
        Uri.parse("$backendURL/classified-gesture?camera_id=$cameraID"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          gestureData[cameraID]?["classified"] = data['classified'] ?? "None";
        });
      }
    } catch (e) {
      print("❌ Error fetching classified gesture for $cameraID: $e");
    }
  }

  Future<void> deleteCamera(String cameraID) async {
    setState(() {
      cameraIDs.remove(cameraID);
      cameraIPs.remove(cameraID);
      espIPs.remove(cameraID);
      gestureData.remove(cameraID);
      detectionEnabled.remove(cameraID);
    });
    await saveConfigurations();
  }

  Color _getStatusColor(String? classified) {
    if (classified == null) return Colors.white70;
    if (classified.contains("Locked")) return Colors.redAccent;
    if (classified.contains("Unlocked")) return Colors.greenAccent;
    return Colors.white70;
  }

  @override
  void dispose() {
    gestureTimer?.cancel();
    cameraIDController.dispose();
    cameraIPController.dispose();
    espIPController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final cardWidth = isLargeScreen ? screenWidth * 0.8 : double.infinity;
    final inputFontSize = isLargeScreen ? 18.0 : 16.0;
    final buttonFontSize = isLargeScreen ? 18.0 : 16.0;
    final titleFontSize = isLargeScreen ? 24.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "CAMERA CONFIG",
          style: GoogleFonts.orbitron(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.black),
        backgroundColor: Colors.tealAccent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, size: isLargeScreen ? 32 : 24, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    currentIP: backendURL.replaceFirst("http://", ""),
                    onSave: (newIP) {
                      setState(() {
                        backendURL = "http://$newIP";
                      });
                    },
                    onDelete: (deletedID) async {
                      setState(() {
                        cameraIDs.remove(deletedID);
                        cameraIPs.remove(deletedID);
                        espIPs.remove(deletedID);
                        gestureData.remove(deletedID);
                        detectionEnabled.remove(deletedID);
                      });
                      await saveConfigurations();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                buildCard(
                  width: cardWidth,
                  title: "Connect Camera & ESP8266",
                  titleFontSize: titleFontSize,
                  children: [
                    buildTextField(
                      "Camera ID",
                      Icons.confirmation_number,
                      cameraIDController,
                      fontSize: inputFontSize,
                    ),
                    SizedBox(height: isLargeScreen ? 20 : 10),
                    buildTextField(
                      "Camera IP",
                      Icons.videocam,
                      cameraIPController,
                      fontSize: inputFontSize,
                    ),
                    SizedBox(height: isLargeScreen ? 20 : 10),
                    ElevatedButton.icon(
                      onPressed: updateCameraIP,
                      icon: Icon(Icons.play_arrow, size: isLargeScreen ? 28 : 24),
                      label: Text(
                        "Set Camera IP & Start",
                        style: TextStyle(fontSize: buttonFontSize),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, isLargeScreen ? 60 : 50),
                        padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 16 : 12),
                      ),
                    ),
                    SizedBox(height: isLargeScreen ? 20 : 10),
                    buildTextField(
                      "ESP8266 IP",
                      Icons.router,
                      espIPController,
                      fontSize: inputFontSize,
                    ),
                    SizedBox(height: isLargeScreen ? 20 : 10),
                    ElevatedButton.icon(
                      onPressed: updateEspIP,
                      icon: Icon(Icons.settings_ethernet, size: isLargeScreen ? 28 : 24),
                      label: Text(
                        "Set ESP IP",
                        style: TextStyle(fontSize: buttonFontSize),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, isLargeScreen ? 60 : 50),
                        padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 16 : 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isLargeScreen ? 30 : 15),
                if (cameraIDs.isNotEmpty)
                  Column(
                    children: cameraIDs.map((cameraID) {
                      final data = gestureData[cameraID] ?? {};
                      return Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: buildCard(
                          width: cardWidth,
                          title: "Gesture Info ($cameraID)",
                          titleFontSize: isLargeScreen ? 22 : 18,
                          children: [
                            InfoRow(
                              icon: "🖐️",
                              label: "Gesture",
                              value: data["gesture"] ?? "None",
                              fontSize: isLargeScreen ? 18 : 16,
                            ),
                            InfoRow(
                              icon: "🤌",
                              label: "Pattern",
                              value: data["fingerPattern"] ?? "N/A",
                              fontSize: isLargeScreen ? 18 : 16,
                            ),
                            InfoRow(
                              icon: "🕒",
                              label: "Timestamp",
                              value: data["timestamp"] ?? "N/A",
                              fontSize: isLargeScreen ? 18 : 16,
                            ),
                            InfoRow(
                              icon: "🔒",
                              label: "Status",
                              value: data["classified"] ?? "None",
                              color: _getStatusColor(data["classified"]),
                              fontSize: isLargeScreen ? 18 : 16,
                            ),
                            if (espIPs[cameraID]?.isNotEmpty ?? false)
                              Padding(
                                padding: EdgeInsets.only(top: isLargeScreen ? 16 : 8),
                                child: Text(
                                  "📡 ESPs: ${espIPs[cameraID]!.join(", ")}",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isLargeScreen ? 18 : 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    required double fontSize,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.tealAccent, fontSize: fontSize),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.tealAccent, fontSize: fontSize),
        prefixIcon: Icon(icon, color: Colors.tealAccent, size: fontSize * 1.6),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.tealAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.tealAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: fontSize * 1.5,
          horizontal: fontSize,
        ),
      ),
    );
  }

  Widget buildCard({
    required String title,
    required List<Widget> children,
    required double width,
    required double titleFontSize,
  }) {
    return Container(
      width: width,
      child: Card(
        color: Colors.grey[850],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.all(titleFontSize),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent,
                ),
              ),
              SizedBox(height: titleFontSize),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? color;
  final double fontSize;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: fontSize * 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: TextStyle(fontSize: fontSize * 1.4)),
          SizedBox(width: fontSize),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$label:",
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: fontSize * 0.3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: color ?? Colors.white70,
                    fontWeight: (value.contains("Locked") || value.contains("Unlocked"))
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}