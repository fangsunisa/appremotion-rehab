import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'progress_analytics.dart'; // นำเข้าหน้า Progress เพื่อเชื่อมโยงกลับไปได้

class ChatMessage {
  final String text;
  final bool isBot;

  ChatMessage({required this.text, required this.isBot});
}

class Chat extends StatefulWidget {
  final String patientId;
  final String patientName;

  const Chat({Key? key, required this.patientId, required this.patientName})
    : super(key: key);

  @override
  State<Chat> createState() => ChatState();
}

class ChatState extends State<Chat> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  String _spokenText = '';
  bool _isChatEnded = false;

  List<ChatMessage> messages = [
    ChatMessage(
      text: 'เก่งมากเลยค่ะ วันนี้ทำกายภาพครบแล้ว\nยอดเยี่ยมมากๆ ... ลองทำท่าเมื่อกี้\nรู้สึกปวดหรือตึงตรงไหนเป็นพิเศษไหมคะ\nเล่าให้ฉันฟังได้เลยนะคะ',
      isBot: true,
    ),
  ];

  String selectedFeeling = 'stiff';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("th-TH");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _speak(messages[0].text);
  }

  Future<void> _speak(String text) async {
    String cleanText = text.replaceAll('\n', ' ');
    await _flutterTts.speak(cleanText);
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _listen() async {
    if (_isChatEnded) return;

    await _flutterTts.stop();

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) => print('Error: $error'),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _spokenText = '';
        });

        _speech.listen(
          onResult: (val) {
            setState(() {
              _spokenText = val.recognizedWords;
            });

            if (val.finalResult && _spokenText.isNotEmpty) {
              _sendMessageToChat(_spokenText);
              _spokenText = '';
              _speech.stop();
            }
          },
          localeId: 'th-TH',
          pauseFor: const Duration(seconds: 3),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();

      if (_spokenText.isNotEmpty) {
        _sendMessageToChat(_spokenText);
        _spokenText = '';
      }
    }
  }

  void _sendMessageToChat(String text) {
    setState(() {
      messages.add(ChatMessage(text: text, isBot: false));
      _isChatEnded = true;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        String botReply =
            'เข้าใจแล้วครับ วันนี้เก่งมากๆ เลย\nเพื่อความแม่นยำ\nเลือกความรู้สึกด้านล่างที่ตรงกับใจ\nแล้วกดบันทึกได้เลยนะครับ';

        setState(() {
          messages.add(ChatMessage(text: botReply, isBot: true));
        });
        _scrollToBottom();

        _speak(botReply);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC7F3FD),
      body: SafeArea(
        child: Column(
          children: [
            // ส่วนหัว (Header)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Column(
                    children: [
                      Text(
                        'Chat',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ประเมินความเจ็บปวดหลังฝึก',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // รายการแชท (ใช้ Expanded เพื่อให้ยืดหยุ่นเต็มพื้นที่ที่เหลือ)
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  if (msg.isBot) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: _buildBotBubble(msg.text),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: _buildUserBubble(msg.text),
                    );
                  }
                },
              ),
            ),

            // ส่วนควบคุมด้านล่าง (ไมโครโฟน, อีโมจิ, ปุ่มบันทึก) อยู่ติดล่างพอดี
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isListening)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'กำลังฟังเสียง... พูดได้เลยครับ',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _isChatEnded ? null : _listen,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isChatEnded
                            ? Colors.grey.shade400
                            : (_isListening
                                  ? Colors.redAccent
                                  : const Color(0xFFC7F3FD)),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          if (!_isChatEnded)
                            BoxShadow(
                              color: _isListening
                                  ? Colors.red.withOpacity(0.4)
                                  : Colors.blue.withOpacity(0.2),
                              spreadRadius: 6,
                              blurRadius: 8,
                            ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic_off : Icons.mic,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_isChatEnded)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'สรุปข้อมูลเรียบร้อยแล้ว',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildEmotionButton('easy.png', 'สบายมาก', 'easy'),
                      _buildEmotionButton('Stiff.png', 'ตึงมาก', 'stiff'),
                      _buildEmotionButton(
                        'Hurts a lot.png',
                        'เจ็บมาก',
                        'hurts',
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        print('บันทึกข้อมูล: $selectedFeeling');
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ProgressAnalyticsScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'บันทึก',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildBotBubble(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white,
          backgroundImage: AssetImage('assets/robot.png'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Color(0xFFDCDCDC),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(15),
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: MediaQuery.of(context).size.width * 0.7,
          padding: const EdgeInsets.all(15),
          decoration: const BoxDecoration(
            color: Color(0xFF4CC2ED),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionButton(String assetName, String label, String value) {
    bool isSelected = selectedFeeling == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFeeling = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Image.asset('assets/$assetName', width: 65, height: 65),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
