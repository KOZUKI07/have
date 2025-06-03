import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hand_gesture_app/screens/camera_control.dart';
import 'package:hand_gesture_app/screens/remote_control.dart';
import 'package:hand_gesture_app/screens/voice_control.dart';
import 'package:lottie/lottie.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late String _greeting;
  String backendURL = "http://192.168.137.1:8001";

  @override
  void initState() {
    super.initState();

    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      _greeting = 'Good Morning !';
    } else if (hour >= 12 && hour < 17) {
      _greeting = 'Good Afternoon !';
    } else if (hour >= 17 && hour < 21) {
      _greeting = 'Good Evening !';
    } else {
      _greeting = 'Good Night !';
    }

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);

    _opacityAnimation = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSecretKeyDialog() {
    final keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Enter Config Code", style: TextStyle(color: Colors.tealAccent)),
          content: TextField(
            controller: keyController,
            obscureText: true,
            style: TextStyle(color: Colors.white),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "Config Code",
              hintStyle: TextStyle(color: Colors.tealAccent),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.tealAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
              onPressed: () {
                final code = keyController.text.trim();
                if (code.isEmpty) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Please enter the config code"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } else {
                  Navigator.pop(context);
                  if (code == "12345") {
                    HapticFeedback.mediumImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CameraControlPage()));
                  } else {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Incorrect Code!"),
                        backgroundColor: Colors.tealAccent,
                      ),
                    );
                  }
                }
              },
              child: Text("Enter", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions and determine device type
    final screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.width > 600;
    
    // Responsive sizing parameters
    final double titleSize = isTablet ? 28.0 : 22.0;
    final double greetingSize = isTablet ? 24.0 : 20.0;
    final double lottieHeight = isTablet ? screenSize.height * 0.4 : 220;
    final double fabSize = isTablet ? 70.0 : 56.0;
    final double iconSize = isTablet ? 34.0 : 28.0;
    final double settingsIconSize = isTablet ? 34.0 : 28.0;
    final EdgeInsets padding = isTablet 
        ? EdgeInsets.symmetric(horizontal: 40, vertical: 30) 
        : EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    final double fabPosition = isTablet ? 40.0 : 20.0;
    final double spacing = isTablet ? 8.0 : 4.0;
    final double verticalSpacing = isTablet ? 60.0 : 40.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      Colors.teal.withOpacity(0.1 * _opacityAnimation.value),
                      Colors.black,
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedOpacity(
                            duration: Duration(milliseconds: 700),
                            opacity: 1.0,
                            child: Text(
                              _greeting,
                              style: GoogleFonts.orbitron(
                                fontSize: greetingSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.tealAccent,
                              ),
                            ),
                          ),
                          SizedBox(height: spacing),
                          Text(
                            'Welcome Home',
                            style: GoogleFonts.orbitron(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.tealAccent,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.settings, 
                            color: Colors.tealAccent, 
                            size: settingsIconSize),
                        onPressed: _showSecretKeyDialog,
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  Center(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            height: lottieHeight,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.tealAccent.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Lottie.asset(
                              'assets/icon/smart_homie.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: fabPosition,
            bottom: fabPosition,
            child: _buildGlowingFAB(
              icon: Icons.settings_remote,
              size: fabSize,
              iconSize: iconSize,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomControlPage(backendURL: backendURL),
                  ),
                );
              },
              tag: 'remote_btn',
              tooltip: 'Remote Control',
            ),
          ),
          Positioned(
            right: fabPosition,
            bottom: fabPosition,
            child: _buildGlowingFAB(
              icon: Icons.mic,
              size: fabSize,
              iconSize: iconSize,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VoiceControlPage(backendURL: backendURL),
                  ),
                );
              },
              tag: 'mic_btn',
              tooltip: 'Voice Command',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingFAB({
    required IconData icon,
    required VoidCallback onPressed,
    required String tag,
    required String tooltip,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.tealAccent.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: tag,
        tooltip: tooltip,
        backgroundColor: Colors.tealAccent,
        shape: CircleBorder(),
        onPressed: onPressed,
        child: Icon(icon, color: Colors.black, size: iconSize),
      ),
    );
  }
}