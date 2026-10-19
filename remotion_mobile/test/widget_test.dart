import 'package:flutter_test/flutter_test.dart';
import 'package:remotion_mobile/main.dart'; // ดึงคลาส MyApp จากไฟล์ main.dart มาใช้ทดสอบ

void main() {
  testWidgets('ตรวจสอบหน้า Home ของแอป', (WidgetTester tester) async {
    // โหลดโครงสร้างแอปทั้งหมด (MyApp) ขึ้นมาจำลองการทดสอบ
    await tester.pumpWidget(const MyApp());

    // ตรวจสอบว่ามีข้อความที่มีคำว่า "ReMotion" บนหน้าจอหรือไม่
    expect(find.textContaining('ReMotion'), findsOneWidget);

    // ตรวจสอบว่ามีปุ่ม "เริ่มต้นเข้าใช้งาน เข้าสู่ระบบ" บนหน้าจอหรือไม่
    expect(find.text('เริ่มต้นเข้าใช้งาน เข้าสู่ระบบ'), findsOneWidget);
  });
}
