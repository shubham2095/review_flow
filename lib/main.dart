import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'screens/auth_gate.dart';

const String kGoogleServerClientId =
    '969050138931-uclne6fp24kgcpjsmfnleeo3ee83vdgp.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
  runApp(const ReviewFlowApp());
}

class ReviewFlowApp extends StatelessWidget {
  const ReviewFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eydia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C6FFF)),
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}
