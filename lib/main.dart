import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/qrscaning_page.dart';

import 'package:internship_duxoff_hub/views/loginpage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QK Wash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: QRScannerPage(),
    );
  }
}
