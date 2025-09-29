import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const String _googleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.94 0 7.1 1.63 9.27 3.01l6.81-6.63C35.67 2.56 30.27 0 24 0 14.82 0 7.1 5.37 3.22 13.22l7.91 6.14C12.81 13.53 17.94 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.5 24.5c0-1.54-.14-3.02-.41-4.46H24v8.42h12.7c-.55 2.95-2.2 5.43-4.65 7.1l7.27 5.63C43.78 37.18 46.5 31.34 46.5 24.5z"/>
  <path fill="#FBBC05" d="M11.13 28.36c-.52-1.56-.81-3.23-.81-4.86s.29-3.3.81-4.86l-7.91-6.14C1.54 15.55 0 19.59 0 23.5s1.54 7.95 4.22 11.0l7.91-6.14z"/>
  <path fill="#34A853" d="M24 47c6.27 0 11.55-2.06 15.39-5.61l-7.27-5.63c-2.02 1.38-4.63 2.2-8.12 2.2-6.06 0-11.19-4.03-12.87-9.5l-7.91 6.14C7.1 42.63 14.82 47 24 47z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Welcome to 🚀\nTrip Capture",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Capture your trips, memories, and adventures seamlessly.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  await authService.signInWithGoogle();
                  // AuthWrapper will auto-navigate on success
                },
                icon: SvgPicture.string(
                  _googleSvg,
                  height: 22,
                  width: 22,
                ),
                label: const Text(
                  'Sign in with Google',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.black12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
