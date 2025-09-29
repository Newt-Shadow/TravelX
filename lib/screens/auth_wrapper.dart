import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'main_navigation.dart';
import '../services/detection_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final detectionService = Provider.of<DetectionService>(context, listen: false);

    if (user == null) {
      // ✅ User is logged out, STOP the service
      detectionService.stop();
      return const LoginScreen();
    } else {
      // ✅ User is logged in, START the service
      detectionService.start();
      return const MainNavigation();
    }

    // if (user == null) {
    //   return const LoginScreen();
    // } else {
    //   return const MainNavigation();
    // }
  }
}