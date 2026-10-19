import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'program.dart';
import 'progress_analytics.dart';

class HistoryScreen extends StatefulWidget {
  final String patientId; // รับไอดีคนไข้เพื่อดึงประวัติ
  final String patientName; // รับชื่อคนไข้ (เผื่อส่งต่อหน้าอื่น)

  const HistoryScreen({
    Key? key,
    this.patientId = '1',
    this.patientName = 'ผู้ป่วย',
  }) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool isLoading = true;
  List<dynamic> historyList = [];

  @override
  void initState() {
    super.initState();
    fetchHistoryData();
  }

  // ฟังก์ชันดึงประวัติการทำกายภาพและบันทึกอาการจาก Backend (MySQL) ผ่าน ApiConfig
  Future<void> fetchHistoryData() async {
    final String url =
        '${ApiConfig.baseUrl}/api/patient/history/${widget.patientId}';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          historyList = data['history'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงประวัติ: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC7F3FD),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProgressAnalyticsScreen(
                            patientId: widget.patientId,
                            patientName: widget.patientName,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 5),
                  const Expanded(
                    child: Text(
                      'บันทึกอาการล่าสุด',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4285F4),
                      ),
                    )
                  : historyList.isEmpty
                  ? const Center(
                      child: Text(
                        'ยังไม่มีประวัติการบันทึกอาการ',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: historyList.map((group) {
                            String monthTitle = group['monthTitle'] ?? '';
                            List logs = group['logs'] ?? [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMonthHeader(monthTitle),
                                const SizedBox(height: 12),
                                ...logs.map((log) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildLogCard(
                                      date: log['date'] ?? '',
                                      status: log['status'] ?? '',
                                      detail: log['detail'] ?? '',
                                      bgColor: _getStatusColor(log['status']),
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 12),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Program(
                  patientId: widget.patientId,
                  patientName: widget.patientName,
                ),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ProgressAnalyticsScreen(
                  patientId: widget.patientId,
                  patientName: widget.patientName,
                ),
              ),
            );
          }
        },
        selectedItemColor: const Color.fromARGB(255, 125, 179, 245),
        unselectedItemColor: const Color.fromARGB(137, 43, 134, 252),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        iconSize: 40,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันเลือกสีการ์ดตามระดับความเจ็บปวด/อาการ
  Color _getStatusColor(String status) {
    if (status.contains('เจ็บมาก') || status.contains('ตึงมาก')) {
      return const Color(0xFFDCEDC8); // เขียวอ่อน / เหลืองอ่อน
    } else if (status.contains('สบาย')) {
      return const Color(0xFFF8BBD0); // ชมพูอ่อน
    }
    return const Color(0xFFF2EBBF); // สีเหลืองนวล
  }

  Widget _buildMonthHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLogCard({
    required String date,
    required String status,
    required String detail,
    required Color bgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calendar_month, color: Colors.red, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
