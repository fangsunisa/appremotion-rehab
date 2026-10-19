import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'history_screen.dart';
import 'program.dart';

class ProgressAnalyticsScreen extends StatefulWidget {
  final String patientId; // รับไอดีคนไข้เพื่อดึงสถิติ
  final String patientName; // รับชื่อคนไข้

  const ProgressAnalyticsScreen({
    Key? key,
    this.patientId = '1',
    this.patientName = 'ผู้ป่วย',
  }) : super(key: key);

  @override
  State<ProgressAnalyticsScreen> createState() =>
      _ProgressAnalyticsScreenState();
}

class _ProgressAnalyticsScreenState extends State<ProgressAnalyticsScreen> {
  int _selectedIndex = 1;
  DateTime _currentMonth = DateTime.now();

  bool isLoading = true;
  int progressPercentage = 0;
  int streakDays = 0;
  int completedDaysCount = 0;
  int partialDaysCount = 0;
  Map<String, String> calendarData = {}; // เก็บสถานะสีรายวัน
  List<dynamic> recentLogs = [];

  // รายชื่อเดือนภาษาไทย
  final List<String> _thaiMonthNames = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  @override
  void initState() {
    super.initState();
    fetchProgressData();
  }

  // ฟังก์ชันดึงสถิติความก้าวหน้าและข้อมูลปฏิทินจาก Backend (MySQL)
  Future<void> fetchProgressData() async {
    int year = _currentMonth.year;
    int month = _currentMonth.month;

    final String url =
        '${ApiConfig.baseUrl}/api/patient/progress/${widget.patientId}?month=$month&year=$year';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          progressPercentage = data['percentage'] ?? 0;
          streakDays = data['streak'] ?? 0;
          completedDaysCount = data['completedDays'] ?? 0;
          partialDaysCount = data['partialDays'] ?? 0;
          calendarData = Map<String, String>.from(data['calendarData'] ?? {});
          recentLogs = data['logs'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงข้อมูลสถิติ: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentMonthName = _thaiMonthNames[_currentMonth.month - 1];

    return Scaffold(
      backgroundColor: const Color(0xFFC7F3FD),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4285F4)),
              )
            : Column(
                children: [
                  _buildHeader(context, currentMonthName),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildOverviewCard(currentMonthName),
                        const SizedBox(height: 16),
                        _buildCalendarCard(),
                        const SizedBox(height: 16),
                        _buildRecentLogsCard(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Program(
                  patientId: widget.patientId,
                  patientName: widget.patientName, // 👈 ส่งชื่อกลับไปด้วย
                ),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryScreen(
                  patientId: widget.patientId,
                  patientName:
                      widget.patientName, // 👈 ส่งชื่อพ่วงไปหน้า History ด้วย
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

  Widget _buildHeader(BuildContext context, String currentMonthName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => Program(
                    patientId: widget.patientId,
                    patientName: widget.patientName, // 👈 ส่งชื่อกลับไปด้วย
                  ),
                ),
              );
            },
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Text(
              'ความก้าวหน้า ($currentMonthName)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String currentMonthName) {
    return _buildCustomCard(
      title: 'ภาพรวม $currentMonthName',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'ความก้าวหน้า',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$progressPercentage %',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 45, color: Colors.grey.shade300),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month, color: Colors.red, size: 30),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ทำต่อเนื่อง',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$streakDays วัน',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    String currentMonthName = _thaiMonthNames[_currentMonth.month - 1];
    int thaiYear = _currentMonth.year + 543;

    return _buildCustomCard(
      title: 'ปฏิทินประจำเดือนความสม่ำเสมอ',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 245,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentMonth = DateTime(
                                _currentMonth.year,
                                _currentMonth.month - 1,
                              );
                              isLoading = true;
                            });
                            fetchProgressData();
                          },
                        ),
                        InkWell(
                          onTap: _showMonthPicker,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '$currentMonthName $thaiYear',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentMonth = DateTime(
                                _currentMonth.year,
                                _currentMonth.month + 1,
                              );
                              isLoading = true;
                            });
                            fetchProgressData();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.']
                          .map((day) {
                            return SizedBox(
                              width: 28,
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    _buildDynamicCalendar(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  _buildLegendItem(
                    Colors.green.shade600,
                    'ครบตามเป้า',
                    '$completedDaysCount วัน',
                  ),
                  const SizedBox(height: 15),
                  _buildLegendItem(
                    Colors.yellow.shade700,
                    'บางส่วน',
                    '$partialDaysCount วัน',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicCalendar() {
    int year = _currentMonth.year;
    int month = _currentMonth.month;

    int firstDayOfWeek = DateTime(year, month, 1).weekday % 7;
    int daysInMonth = DateTime(year, month + 1, 0).day;

    List<Widget> dayWidgets = [];

    for (int i = 0; i < firstDayOfWeek; i++) {
      dayWidgets.add(const SizedBox(width: 28, height: 28));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      String dateKey =
          "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

      Color bgColor = Colors.transparent;
      Border? border = Border.all(color: Colors.grey.shade300);

      if (calendarData[dateKey] == 'green') {
        bgColor = Colors.green.shade600;
        border = null;
      } else if (calendarData[dateKey] == 'yellow') {
        bgColor = Colors.yellow.shade700;
        border = null;
      }

      dayWidgets.add(
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 10,
                color: bgColor != Colors.transparent
                    ? Colors.white
                    : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      alignment: WrapAlignment.start,
      children: dayWidgets,
    );
  }

  void _showMonthPicker() {
    int thaiYear = _currentMonth.year + 543;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'เลือกเดือน',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: 12,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('${_thaiMonthNames[index]} $thaiYear'),
                  onTap: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, index + 1);
                      isLoading = true;
                    });
                    fetchProgressData();
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentLogsCard() {
    return _buildCustomCard(
      title: 'บันทึกอาการล่าสุด',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryScreen(
              patientId: widget.patientId,
              patientName: widget.patientName, // 👈 ส่งชื่อไปด้วย
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: recentLogs.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'ยังไม่มีบันทึกอาการล่าสุด',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : Column(
                children: recentLogs.map((log) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildLogItem(
                      date: log['date'] ?? '-',
                      status: log['status'] ?? '-',
                      detail: log['detail'] ?? '',
                      bgColor: const Color(0xFFDCEDC8),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildCustomCard({
    required String title,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          highlightColor: Colors.blue.withOpacity(0.1),
          splashColor: Colors.blue.withOpacity(0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: const BoxDecoration(color: Color(0xFF4285F4)),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogItem({
    required String date,
    required String status,
    required String detail,
    required Color bgColor,
  }) {
    return Container(
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
