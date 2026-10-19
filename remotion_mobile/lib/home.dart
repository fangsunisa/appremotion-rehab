import 'package:flutter/material.dart';

import 'signin.dart'; // ดึงหน้า signin เข้ามาเพื่อใช้เปลี่ยนหน้า

class Home extends StatelessWidget {
  const Home({super.key}); // หน้าแรกสุด ไม่ต้องรับ patientId

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC7F3FD),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            const Icon(Icons.home, size: 100, color: Color(0xFF4CC2ED)),
            const SizedBox(height: 15),
            const Text(
              'ReMotion',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Color(0xFF265A73),
              ),
            ),
            const Text(
              'Rehab',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Color(0xFF265A73),
              ),
            ),
            const SizedBox(height: 60),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.scale(
                  scale: 3.0,
                  child: Image.asset(
                    'assets/logo.png',
                    width: 240,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    // กดแล้วพาไปยังหน้า Sign In
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Signin()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CC2ED),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'เริ่มต้นเข้าใช้งาน เข้าสู่ระบบ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 160),
          ],
        ),
      ),
    );
  }
}
