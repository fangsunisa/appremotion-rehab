import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'exercise_prescription.dart';
import 'exercise_screen.dart';
import 'history_screen.dart';
import 'progress_analytics.dart';

class Program extends StatefulWidget {
  final String patientName; // รับชื่อจริงของคนไข้ที่ล็อกอินเข้ามา
  final String patientId; // รับรหัสไอดีคนไข้เพื่อใช้ดึงข้อมูล

  const Program({Key? key, required this.patientName, required this.patientId})
    : super(key: key);

  @override
  State<Program> createState() => _ProgramState();
}

class _ProgramState extends State<Program> {
  int _selectedIndex = 0;

  bool hasProgram = false;
  bool isLoading = true; // ตั้งค่าเป็น true ตอนเริ่มเปิดหน้าจอเพื่อรอโหลดข้อมูล
  List<dynamic> programList = []; // เก็บรายการโปรแกรมที่ดึงมาจากฐานข้อมูล

  // 👉 ตัวแปรนับจำนวนท่าที่ทำเสร็จแล้ว
  int completedExerciseCount = 0;

  @override
  void initState() {
    super.initState();
    fetchPatientProgram(widget.patientId);
  }

  // ฟังก์ชันยิง API ไปดึงโปรแกรมจาก Node.js Backend
  Future<void> fetchPatientProgram(String patientId) async {
    final String url = '${ApiConfig.baseUrl}/api/patient/program/$patientId';
    final String progressUrl =
        '${ApiConfig.baseUrl}/api/patient/progress/$patientId';

    try {
      // 1. ดึงโปรแกรมกายภาพ
      final response = await http.get(Uri.parse(url));
      // 2. ดึงข้อมูล progress เพื่อเช็กว่าวันนี้ทำหรือยัง
      final progressResponse = await http.get(Uri.parse(progressUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        int todayCompletedReps = 0;
        // ถ้าดึง progress สำเร็จ และวันนี้ทำเสร็จแล้ว (percentage == 100)
        if (progressResponse.statusCode == 200) {
          final progressData = jsonDecode(progressResponse.body);
          if (progressData['isTodayCompleted'] == true) {
            todayCompletedReps =
                data.length; // กำหนดให้ทำครบทุกท่าตามจำนวนโปรแกรม
          }
        }
        setState(() {
          programList = data;
          hasProgram = data.isNotEmpty;
          completedExerciseCount =
              todayCompletedReps; // 👉 อัปเดตสถานะว่าวันนี้ทำเสร็จหรือยัง
          isLoading = false;
        });
      } else {
        setState(() {
          hasProgram = false;
          isLoading = false;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงโปรแกรม: $e');
      setState(() {
        hasProgram = false;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC7F3FD),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4285F4)),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. แถบด้านบน
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.account_circle_outlined, size: 32),
                            const Text(
                              'ReMotion Rehab',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CC2ED),
                              ),
                            ),
                            const SizedBox(width: 32),
                          ],
                        ),
                      ),

                      // 2. ข้อความต้อนรับ (แสดงชื่อจริงของคนไข้)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สวัสดีครับ, ${widget.patientName}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'เริ่มต้นโปรแกรม',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'โปรแกรมของคุณ',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // 3. เช็กว่ามีโปรแกรมจากฐานข้อมูลหรือไม่
                      hasProgram ? _buildProgramContent() : _buildEmptyState(),
                    ],
                  ),
                ),
              ),
      ),

      // 4. เมนูด้านล่าง
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == _selectedIndex) return;

          setState(() {
            _selectedIndex = index;
          });

          if (index == 0) {
            // อยู่หน้า Home แล้ว
          } else if (index == 1) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProgressAnalyticsScreen(
                  patientId: widget.patientId,
                  patientName: widget.patientName,
                ),
              ),
            );
            if (result != null && result is int) {
              setState(() {
                completedExerciseCount = result;
              });
            }
          } else if (index == 2) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryScreen(
                  patientId: widget.patientId,
                  patientName: widget.patientName,
                ),
              ),
            );
            if (result != null && result is int) {
              setState(() {
                completedExerciseCount = result;
              });
            }
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

  // หน้าจอแสดงผลเมื่อ "ยังไม่มีโปรแกรม"
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.folder_off_outlined, size: 80, color: Colors.black26),
          SizedBox(height: 16),
          Text(
            'ยังไม่มีโปรแกรมกายภาพ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'กรุณารอแพทย์ประเมิน\nและจัดโปรแกรมให้คุณ',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  // หน้าจอแสดงผลเมื่อมีโปรแกรมจากฐานข้อมูลแล้ว (แสดงกล่องสรุป + รายการท่าทั้งหมด)
  Widget _buildProgramContent() {
    List<ExercisePrescription> prescriptions = programList.map((item) {
      return ExercisePrescription(
        exerciseId: item['ExerciseID']?.toString() ?? '',
        exerciseName: item['Exercise_Name'] ?? 'ท่าออกกำลังกาย',
        targetReps: item['Target_Reps'] ?? 10,
        targetSets: item['Target_Sets'] ?? 3,
        holdSeconds: 0,
      );
    }).toList();

    // เช็กว่าทำครบทุกท่าแล้วหรือยัง
    bool isAllCompleted =
        programList.isNotEmpty && completedExerciseCount >= programList.length;

    return Column(
      children: [
        // 1. กล่องสรุปด้านบน
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'โปรแกรมวันนี้: รักษาและฟื้นฟูร่างกาย',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: programList.isNotEmpty
                              ? completedExerciseCount / programList.length
                              : 0.0,
                          strokeWidth: 6,
                          backgroundColor: const Color(0xFFEEEEEE),
                          color: const Color(0xFF4285F4),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$completedExerciseCount/${programList.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('สำเร็จ', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: isAllCompleted
                        ? null // ถ้าทำครบแล้ว ปิดการกดปุ่ม
                        : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExerciseScreen(
                                  prescriptions: prescriptions,
                                  patientId: widget.patientId,
                                  patientName: widget.patientName,
                                  onExerciseFinished: (completedCount) {
                                    setState(() {
                                      completedExerciseCount = completedCount;
                                    });
                                  },
                                  onComplete: () {
                                    setState(() {
                                      completedExerciseCount =
                                          programList.length;
                                    });
                                  },
                                ),
                              ),
                            );
                            if (result != null && result is int) {
                              setState(() {
                                completedExerciseCount = result;
                              });
                            }
                            fetchPatientProgram(widget.patientId);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAllCompleted
                          ? Colors.grey
                          : const Color(0xFF4285F4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isAllCompleted
                          ? 'เสร็จสิ้นแล้ว'
                          : 'เริ่มเลย', // 👉 เปลี่ยนข้อความตามสถานะการทำครบ
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // 2. รายการท่าออกกำลังกายที่ดึงมาจากฐานข้อมูล MySQL จริงๆ
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: programList.length,
          itemBuilder: (context, index) {
            final item = programList[index];

            final exerciseName = item['Exercise_Name'] ?? 'ท่าออกกำลังกาย';
            final targetReps = item['Target_Reps'] ?? 10;
            final targetSets = item['Target_Sets'] ?? 3;

            // เช็กสถานะ: ถ้า index น้อยกว่าจำนวนท่าที่ทำเสร็จ ให้ขึ้นว่าสำเร็จแล้ว
            bool isItemCompleted = index < completedExerciseCount;
            // เช็กสถานะ: ถ้ายังไม่เสร็จและเป็นตัวปัจจุบัน ให้ขึ้นว่ากำลังทำ
            bool isCurrent = index == completedExerciseCount;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. $exerciseName',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$targetSets เซท , $targetReps ครั้ง',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isItemCompleted
                          ? Colors.green
                          : (isCurrent ? Colors.amber[700] : Colors.grey[400]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isItemCompleted
                          ? 'สำเร็จแล้ว'
                          : (isCurrent ? 'กำลังทำ' : 'ยังไม่ได้ทำ'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
