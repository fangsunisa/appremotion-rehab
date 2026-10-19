import 'package:flutter/material.dart';

import 'home.dart'; // เริ่มต้นที่หน้าแรก
import 'chat.dart'; // เริ่มต้นที่หน้า Chat

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReMotion Rehab',
      theme: ThemeData(primarySwatch: Colors.cyan),
      home: const Home(), // เปิดแอปมาเจอหน้า Home
      //home: const Chat(patientId: '1', patientName: 'คุณผู้ป่วย'),
    );
  }
}
