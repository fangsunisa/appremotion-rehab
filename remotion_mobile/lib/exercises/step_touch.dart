import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mp_pose_landmarker/flutter_mp_pose_landmarker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';

import '../chat.dart';
import '../exercise_prescription.dart';

class StepTouch extends StatefulWidget {
  final List<ExercisePrescription> prescriptions;
  final VoidCallback? onComplete;

  const StepTouch({Key? key, required this.prescriptions, this.onComplete})
    : super(key: key);

  @override
  State<StepTouch> createState() => _StepTouchState();
}

class _StepTouchState extends State<StepTouch> {
  StreamSubscription<PoseLandMarker>? _poseSubscription;
  List<PoseLandmarkPoint> _landmarks = [];
  bool _personDetected = false;

  int currentExerciseIndex = 0;
  ExercisePrescription get prescription =>
      widget.prescriptions[currentExerciseIndex];

  late FlutterTts _flutterTts;
  String _lastSpokenMessage = '';

  int get targetRep => prescription.targetReps;
  int get targetSet => prescription.targetSets;
  int get holdTargetSeconds => 10;

  int currentRep = 0;
  int completedSets = 0;

  bool _hasSteppedOut = false;

  Timer? _holdTimer;

  bool _isResting = false;
  bool _exerciseCompleted = false;

  bool _isWatchingInstruction = true;
  bool _exerciseReady = false;

  VideoPlayerController? _videoController;
  bool _videoFinished = false;
  bool _videoLoading = true;
  String? _videoErrorMessage;

  String feedbackMessage = 'กำลังตรวจจับท่าทาง...';
  String warningMessage = '';

  DateTime? _lastWarningTime;

  @override
  void initState() {
    super.initState();
    _startEverything();
  }

  Future<void> _startEverything() async {
    await _initTts();
    _startPoseDetection();
    _initializeVideo();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('th-TH');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _speak(String text, {bool force = false}) async {
    if (text.isEmpty) return;
    if (!force && text == _lastSpokenMessage) return;
    _lastSpokenMessage = text;
    await _flutterTts.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await _flutterTts.speak(text);
  }

  Future<void> _initializeVideo() async {
    String videoAsset = 'assets/videos/step_touch.mp4';

    if (_videoController != null) {
      _videoController!.removeListener(_onVideoProgress);
      await _videoController!.dispose();
      _videoController = null;
    }

    if (mounted) {
      setState(() {
        _videoLoading = true;
        _videoErrorMessage = null;
        _videoFinished = false;
        _isWatchingInstruction = true;
        _exerciseReady = false;
      });
    }

    final controller = VideoPlayerController.asset(videoAsset);
    _videoController = controller;

    try {
      await controller.initialize().timeout(const Duration(seconds: 10));
      if (!mounted) return;

      await controller.setLooping(false);
      controller.addListener(_onVideoProgress);

      setState(() {
        _videoLoading = false;
        _videoErrorMessage = null;
      });

      await controller.seekTo(Duration.zero);
      await controller.play();
    } catch (e) {
      debugPrint('Video initialization failed: $e');
      if (!mounted) return;

      setState(() {
        _videoLoading = false;
        _videoErrorMessage = 'เปิดวิดีโอสอนไม่ได้';
      });
    }
  }

  void _onVideoProgress() {
    if (_videoController == null ||
        !_videoController!.value.isInitialized ||
        _videoFinished) {
      return;
    }

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;

    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 200)) {
      _videoFinished = true;
      _finishInstructionVideo();
    }
  }

  Future<void> _finishInstructionVideo() async {
    if (!mounted) return;

    await _videoController?.pause();
    await _videoController?.dispose();
    _videoController = null;

    setState(() {
      _isWatchingInstruction = false;
      _exerciseReady = false;
      feedbackMessage = 'วิดีโอสอนจบแล้ว กำลังเตรียมเริ่มทำท่า';
      warningMessage = '';
    });

    await _speak(
      'ดูวิดีโอตัวอย่างจบแล้วค่ะ เริ่มทำท่า ${prescription.exerciseName} '
      'ยืนตรง เท้าชิดกัน มือเท้าเอว ก้าวขาออกด้านข้าง แล้วก้าวขาอีกข้างมาตามชิดได้เลยค่ะ',
      force: true,
    );

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _exerciseReady = true;
          feedbackMessage = 'เริ่มทำท่า ${prescription.exerciseName} ได้เลยค่ะ';
          warningMessage = 'ยืนตรง | เท้าชิด | มือเท้าเอว';
        });
      }
    });
  }

  Future<void> _startExerciseWithoutVideo() async {
    if (!mounted) return;

    await _videoController?.pause();
    await _videoController?.dispose();
    _videoController = null;

    setState(() {
      _isWatchingInstruction = false;
      _exerciseReady = false;
      _videoFinished = true;
      feedbackMessage = 'กำลังเตรียมกล้อง...';
      warningMessage = '';
    });

    await _speak(
      'เริ่มต้นทำท่า ${prescription.exerciseName} '
      'ยืนตรง เท้าชิดกัน มือเท้าเอว ก้าวขาออกด้านข้าง แล้วก้าวขาอีกข้างมาตามชิดได้เลยค่ะ',
      force: true,
    );

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _exerciseReady = true;
          feedbackMessage = 'เริ่มทำท่าได้เลยค่ะ';
          warningMessage = 'ยืนตรง | เท้าชิด | มือเท้าเอว';
        });
      }
    });
  }

  Future<void> _startPoseDetection() async {
    try {
      final granted = await PoseLandmarker.checkCameraPermission();
      if (!granted) {
        await PoseLandmarker.requestCameraPermission();
      }

      PoseLandmarker.setConfig(
        delegate: 0,
        model: 1,
        minPoseDetectionConfidence: 0.5,
        minPoseTrackingConfidence: 0.5,
        minPosePresenceConfidence: 0.4,
        analysisWidth: 320,
        analysisHeight: 240,
      );

      _poseSubscription = PoseLandmarker.poseLandmarkStream.listen((pose) {
        if (!mounted) return;
        final landmarks = pose.landmarks;

        bool hasValidBody = false;
        if (landmarks.length >= 33) {
          final leftHip = landmarks[23];
          final rightHip = landmarks[24];
          if (leftHip.presence > 0.2 || rightHip.presence > 0.2) {
            hasValidBody = true;
          }
        }

        setState(() {
          _landmarks = landmarks;
          _personDetected = hasValidBody;

          if (!_personDetected) {
            feedbackMessage = 'กรุณายืนให้อยู่ในบริเวณกล้อง';
            warningMessage = '';
          }
        });

        if (_exerciseReady &&
            !_isWatchingInstruction &&
            _personDetected &&
            !_exerciseCompleted &&
            !_isResting) {
          _checkExercise();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        feedbackMessage = 'ไม่สามารถเปิดกล้องได้';
        warningMessage = e.toString();
      });
    }
  }

  double _calculateAngle(
    PoseLandmarkPoint a,
    PoseLandmarkPoint b,
    PoseLandmarkPoint c,
  ) {
    final radians =
        math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    double angle = radians.abs() * 180 / math.pi;
    if (angle > 180) {
      angle = 360 - angle;
    }
    return angle;
  }

  bool _isFacingCamera() {
    if (_landmarks.length < 33) return false;
    double shoulderWidth = (_landmarks[11].x - _landmarks[12].x).abs();
    return shoulderWidth > 0.08;
  }

  bool _isStandingPosture() {
    if (_landmarks.length < 33) return false;
    double leftHipAngle = _calculateAngle(
      _landmarks[11],
      _landmarks[23],
      _landmarks[25],
    );
    double rightHipAngle = _calculateAngle(
      _landmarks[12],
      _landmarks[24],
      _landmarks[26],
    );
    double hipAngle = (leftHipAngle + rightHipAngle) / 2;
    return hipAngle >= 95;
  }

  bool _isFeetTogether() {
    if (_landmarks.length < 33) return false;
    final leftAnkle = _landmarks[27];
    final rightAnkle = _landmarks[28];
    final leftHip = _landmarks[23];
    final rightHip = _landmarks[24];

    double hipWidth = (leftHip.x - rightHip.x).abs();
    if (hipWidth == 0) hipWidth = 0.1;

    double ankleDistance = (leftAnkle.x - rightAnkle.x).abs();
    return ankleDistance < (hipWidth * 1.3);
  }

  bool _isStepOut() {
    if (_landmarks.length < 33) return false;
    final leftAnkle = _landmarks[27];
    final rightAnkle = _landmarks[28];
    final leftHip = _landmarks[23];
    final rightHip = _landmarks[24];

    double hipWidth = (leftHip.x - rightHip.x).abs();
    if (hipWidth == 0) hipWidth = 0.1;

    double ankleDistance = (leftAnkle.x - rightAnkle.x).abs();
    return ankleDistance > (hipWidth * 1.5);
  }

  void _checkExercise() {
    if (!_personDetected || _isResting || _exerciseCompleted) return;

    if (!_isFacingCamera()) {
      setState(() {
        feedbackMessage = 'กรุณาหันหน้าตรงเข้าหากล้อง';
        warningMessage = 'หันหน้าตรงเข้าหากล้อง';
      });
      return;
    }

    if (!_isStandingPosture()) {
      setState(() {
        feedbackMessage = 'กรุณายืนตรง';
        warningMessage = 'ยืนตรง เท้าชิดกัน';
      });
      return;
    }

    bool stepOut = _isStepOut();
    bool feetTogether = _isFeetTogether();

    if (stepOut) {
      _hasSteppedOut = true;
      setState(() {
        feedbackMessage = 'ก้าวขาออกด้านข้างถูกต้อง! ดึงเท้าอีกข้างมาประกบชิด';
        warningMessage = '';
      });
    } else if (_hasSteppedOut && feetTogether) {
      _hasSteppedOut = false;
      _completeOneRep(); // นับจำนวนก้าวสะสมในเซตนี้
    } else {
      setState(() {
        feedbackMessage = 'กำลังทำท่า: ${prescription.exerciseName}';
        warningMessage = 'ก้าวขาออกด้านข้าง แล้วก้าวชิด';
      });
    }
  }

  void _completeOneRep() {
    if (!mounted || _exerciseCompleted) return;
    currentRep++;

    String exerciseName = prescription.exerciseName;

    // ถ้ายังนับก้าวไม่ครบตามเป้าหมายต่อเซต (เช่น ยังไม่ถึง 10 ก้าว)
    if (currentRep < targetRep) {
      _speak('$currentRep', force: true);
      setState(() {
        feedbackMessage = 'ก้าวที่ $currentRep แล้ว ทำต่อไปค่ะ';
        warningMessage = 'ก้าวสลับข้างต่อไป';
      });
      return;
    }

    // ถ้าทำครบจำนวนก้าวในเซตนี้แล้ว (เช่น ครบ 10 ก้าว) ให้รีเซ็ตจำนวนก้าวแล้วเข้าสู่กระบวนการจบเซต
    currentRep = 0;
    setState(() {
      feedbackMessage = 'เยี่ยมมาก จบ 1 เซตของท่า $exerciseName แล้วค่ะ';
      warningMessage = 'พักผ่อนสักครู่';
    });
    _completeSet();
  }

  void _completeSet() {
    completedSets++;
    String exerciseName = prescription.exerciseName;

    if (completedSets >= targetSet) {
      if (currentExerciseIndex < widget.prescriptions.length - 1) {
        setState(() {
          currentExerciseIndex++;
          completedSets = 0;
          currentRep = 0;
          _isResting = false;
          feedbackMessage = 'ยอดเยี่ยม! กำลังเปลี่ยนไปท่าถัดไป';
          warningMessage = 'เตรียมพร้อมท่าต่อไป';
        });
        _speak(
          'ยอดเยี่ยมมากค่ะ ทำท่านี้ครบทุกเซตแล้ว กำลังเปลี่ยนไปท่าถัดไปค่ะ',
          force: true,
        );
        _initializeVideo();
        return;
      } else {
        setState(() {
          _exerciseCompleted = true;
          _isResting = true;
          feedbackMessage = 'ออกกำลังกายครบทุกท่าของวันนี้แล้ว!';
          warningMessage = 'ทำครบทุกท่าแล้ว 🎉';
        });
        _speak(
          'ยอดเยี่ยมมากค่ะ วันนี้ออกกำลังกายครบทุกท่าแล้วค่ะ กำลังพาไปหน้าสรุปผลค่ะ',
          force: true,
        );

        Future.delayed(const Duration(seconds: 5), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Chat()),
          );
        });
        return;
      }
    }

    setState(() {
      _isResting = true;
      feedbackMessage =
          'พักผ่อนสักครู่ 20 วินาที กำลังเริ่มเซตถัดไปของท่า $exerciseName...';
      warningMessage = 'พักระหว่างเซต (20 วินาที)';
    });

    _speak(
      'ยอดเยี่ยม จบเซตนี้แล้วค่ะ พักผ่อนสักครู่ 20 วินาทีนะคะ',
      force: true,
    );

    Future.delayed(const Duration(seconds: 20), () {
      if (!mounted) return;
      setState(() {
        _isResting = false;
        currentRep = 0;
        feedbackMessage = 'เริ่มทำเซตต่อไปของท่า $exerciseName ได้เลยค่ะ';
        warningMessage = 'เตรียมพร้อมเซตใหม่';
      });
      _speak('พักผ่อนครบแล้ว เริ่มทำเซตต่อไปได้เลยค่ะ', force: true);
    });
  }

  @override
  void dispose() {
    _poseSubscription?.cancel();
    _holdTimer?.cancel();
    _flutterTts.stop();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC7F3FD),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            const headerHeight = 58.0;
            final finalCameraHeight = screenHeight * 0.52;

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  height: headerHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFFC7F3FD),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 26,
                          color: Colors.black87,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          prescription.exerciseName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B4954),
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            width: screenWidth,
                            height: finalCameraHeight,
                            child: ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const NativeCameraPreview(),
                                  IgnorePointer(
                                    child: CustomPaint(
                                      painter: MediaPipeSkeletonPainter(
                                        _landmarks,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: _cameraStatusChip(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              color: const Color(0xFFC7F3FD),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Flexible(
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4036),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: SingleChildScrollView(
                                        child: Text(
                                          warningMessage.isNotEmpty
                                              ? warningMessage
                                              : 'แจ้งเตือน: ยืนตรง เท้าชิดกัน',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Flexible(
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEB3B),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: SingleChildScrollView(
                                        child: Text(
                                          'Feedback: $feedbackMessage',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _bottomCounter(
                                          title: 'จำนวนก้าว',
                                          value: '$currentRep/$targetRep',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _bottomCounter(
                                          title: 'เซต',
                                          value: '$completedSets/$targetSet',
                                        ),
                                      ),
                                    ],
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _exerciseCompleted
                                          ? 'ทำครบทุกท่าแล้ว'
                                          : _isResting
                                          ? 'กำลังพัก'
                                          : 'กำลังฝึกท่าก้าวเท้า',
                                      style: const TextStyle(
                                        color: Color(0xFF1B4954),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Offstage(
                        offstage: !_isWatchingInstruction,
                        child: Container(
                          color: Colors.black,
                          child: _buildInstructionVideo(screenWidth),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInstructionVideo(double screenWidth) {
    if (_videoErrorMessage != null) {
      return Container(
        width: screenWidth,
        color: Colors.black,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_library_outlined,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 20),
              Text(
                _videoErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startExerciseWithoutVideo,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text('เริ่มทำท่าเลย', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_videoLoading ||
        _videoController == null ||
        !_videoController!.value.isInitialized) {
      return Container(
        width: screenWidth,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: screenWidth,
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _cameraStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _personDetected ? Icons.person : Icons.person_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            _personDetected ? 'ตรวจพบ' : 'กำลังตรวจจับ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomCounter({required String title, required String value}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$title: ',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NativeCameraPreview extends StatelessWidget {
  const NativeCameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const SizedBox.expand(
          child: AndroidView(
            viewType: 'camera_preview_view',
            layoutDirection: TextDirection.ltr,
          ),
        );
      case TargetPlatform.iOS:
        return const SizedBox.expand(
          child: UiKitView(
            viewType: 'camera_preview_view',
            layoutDirection: TextDirection.ltr,
          ),
        );
      default:
        return const Center(
          child: Text('Native camera preview รองรับเฉพาะ Android และ iOS'),
        );
    }
  }
}

class MediaPipeSkeletonPainter extends CustomPainter {
  final List<PoseLandmarkPoint> landmarks;
  static final Map<int, Offset> _smoothedPoints = {};

  const MediaPipeSkeletonPainter(this.landmarks);

  static const List<List<int>> connections = [
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
    [11, 23],
    [12, 24],
    [23, 24],
    [23, 25],
    [25, 27],
    [27, 31],
    [24, 26],
    [26, 28],
    [28, 32],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color(0xFF65F0C0)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = const Color(0xFFFF4B61)
      ..style = PaintingStyle.fill;

    final Map<int, Offset> currentPoints = {};
    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      if (lm.presence < 0.15) continue;

      final rawX = (1.0 - lm.x) * size.width;
      final rawY = lm.y * size.height;
      final rawOffset = Offset(rawX, rawY);

      if (_smoothedPoints.containsKey(i)) {
        final prev = _smoothedPoints[i]!;
        final smoothedX = prev.dx + 0.4 * (rawOffset.dx - prev.dx);
        final smoothedY = prev.dy + 0.4 * (rawOffset.dy - prev.dy);
        currentPoints[i] = Offset(smoothedX, smoothedY);
      } else {
        currentPoints[i] = rawOffset;
      }
    }
    _smoothedPoints.clear();
    _smoothedPoints.addAll(currentPoints);

    for (final connection in connections) {
      final startIndex = connection[0];
      final endIndex = connection[1];

      if (!currentPoints.containsKey(startIndex) ||
          !currentPoints.containsKey(endIndex)) {
        continue;
      }

      canvas.drawLine(
        currentPoints[startIndex]!,
        currentPoints[endIndex]!,
        linePaint,
      );
    }

    currentPoints.forEach((i, point) {
      if (i >= 11) {
        canvas.drawCircle(point, 5.0, pointPaint);
      }
    });
  }

  @override
  bool shouldRepaint(covariant MediaPipeSkeletonPainter oldDelegate) {
    return true;
  }
}
