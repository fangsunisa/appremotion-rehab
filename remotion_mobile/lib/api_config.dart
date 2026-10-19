class ApiConfig {
  static const bool useLocalServer = true;
  static const String baseUrl = useLocalServer
      ? 'http://172.20.10.3:3000' // IP เครื่องฟาง
      : 'https://remotion-backend-czpr.onrender.com'; // ลิงก์บนคลาวด์
}
