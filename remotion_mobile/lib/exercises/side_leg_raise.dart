import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mp_pose_landmarker/flutter_mp_pose_landmarker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';

import '../chat.dart';
import '../exercise_prescription.dart';

class SideLegRaise extends StatefulWidget {
  final List<ExercisePrescription> prescriptions;
  final VoidCallback? onComplete;

  const SideLegRaise({Key? key, required this.prescriptions, this.onComplete})
    : super(key: key);

  @override
  State<SideLegRaise> createState() => _SideLegRaiseState();
}

class _SideLegRaiseState extends State<SideLegRaise> {
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

  String currentLeg = 'ซ้าย';
  int currentRep = 0;
  int completedSets = 0;

  Timer? _holdTimer;
  int _holdSeconds = 0;
  bool _isHoldingCorrectPose = false;

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
    // 👈 ดึงชื่อท่าจาก prescription ให้ถูกต้อง
    String exerciseName = prescription.exerciseName;

    // 👈 ประกาศตัวแปร videoAsset ครั้งเดียวพอ
    String videoAsset = 'assets/videos/side_leg_raise.mp4';
    if (exerciseName.contains('ด้านข้าง') || exerciseName.contains('กางขา')) {
      videoAsset = 'assets/videos/side_leg_raise.mp4';
    }

    if (_videoController != null) {
      final oldController = _videoController;
      _videoController = null;
      oldController?.removeListener(_onVideoProgress);
      await oldController?.dispose();
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
      _exerciseReady = true;
      feedbackMessage = 'เริ่มทำท่า ${prescription.exerciseName} ได้เลยค่ะ';
      warningMessage = 'หันหน้าตรง | เริ่มจากขาซ้าย';
    });

    await _speak(
      'ดูวิดีโอตัวอย่างจบแล้วค่ะ เริ่มทำท่า ${prescription.exerciseName} '
      'เริ่มจากขาซ้ายก่อนนะคะ หันหน้าตรงเข้าหากล้อง แล้วทำตามท่าตามวิดีโอได้เลยค่ะ',
      force: true,
    );
  }

  Future<void> _startExerciseWithoutVideo() async {
    if (!mounted) return;

    await _videoController?.pause();
    await _videoController?.dispose();
    _videoController = null;

    setState(() {
      _isWatchingInstruction = false;
      _exerciseReady = true;
      _videoFinished = true;
      feedbackMessage = 'เริ่มทำท่าขาซ้ายได้เลยค่ะ';
      warningMessage = 'หันหน้าตรง | เริ่มจากขาซ้าย';
    });

    await _speak(
      'ไม่สามารถเปิดวิดีโอตัวอย่างได้ค่ะ '
      'เริ่มจากขาซ้ายก่อนนะคะ หันหน้าตรงเข้าหากล้อง '
      'แล้วทำตามท่าที่กำหนดได้เลยค่ะ',
      force: true,
    );
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

    final leftHipY = _landmarks[23].y;
    final rightHipY = _landmarks[24].y;
    final leftKneeY = _landmarks[25].y;
    final rightKneeY = _landmarks[26].y;

    bool isLeftStanding = leftHipY < (leftKneeY - 0.12);
    bool isRightStanding = rightHipY < (rightKneeY - 0.12);

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

    if ((isLeftStanding || isRightStanding) && hipAngle >= 95) {
      return true;
    }
    return false;
  }

  bool _isLeftLegAbducted() {
    if (_landmarks.length < 33) return false;

    double kneeAngle = _calculateAngle(
      _landmarks[23],
      _landmarks[25],
      _landmarks[27],
    );
    if (kneeAngle < 150) return false;

    final leftAnkle = _landmarks[27];
    final leftHip = _landmarks[23];
    final rightHip = _landmarks[24];
    final rightAnkle = _landmarks[28];

    double hipWidth = (leftHip.x - rightHip.x).abs();
    if (hipWidth == 0) hipWidth = 0.1;

    double ankleDistance = (leftAnkle.x - leftHip.x).abs();
    bool isOutward = ankleDistance > (hipWidth * 1.25);
    bool isLifted = leftAnkle.y < (rightAnkle.y + 0.1);

    return isOutward && isLifted;
  }

  bool _isRightLegAbducted() {
    if (_landmarks.length < 33) return false;

    double kneeAngle = _calculateAngle(
      _landmarks[24],
      _landmarks[26],
      _landmarks[28],
    );
    if (kneeAngle < 150) return false;

    final rightAnkle = _landmarks[28];
    final leftHip = _landmarks[23];
    final rightHip = _landmarks[24];
    final leftAnkle = _landmarks[27];

    double hipWidth = (leftHip.x - rightHip.x).abs();
    if (hipWidth == 0) hipWidth = 0.1;

    double ankleDistance = (rightAnkle.x - rightHip.x).abs();
    bool isOutward = ankleDistance > (hipWidth * 1.25);
    bool isLifted = rightAnkle.y < (leftAnkle.y + 0.1);

    return isOutward && isLifted;
  }

  void _checkExercise() {
    if (!_personDetected ||
        _isResting ||
        _exerciseCompleted ||
        _isHoldingCorrectPose) {
      return;
    }

    String exerciseName = prescription.exerciseName;

    if (!_isFacingCamera()) {
      _stopHoldTimer();
      setState(() {
        feedbackMessage = 'ทำผิดท่า! กรุณาหันหน้าตรงเข้าหากล้อง';
        warningMessage = 'ทำผิดท่า: กรุณาหันหน้าตรง';
      });
      _speakWarning('ทำผิดท่าค่ะ กรุณาหันหน้าตรงเข้าหากล้องนะคะ');
      return;
    }

    if (!_isStandingPosture()) {
      _stopHoldTimer();
      setState(() {
        feedbackMessage = 'ทำผิดท่า! ต้องยืนขึ้นเพื่อทำท่านี้ (ห้ามนั่งทำ)';
        warningMessage = 'ทำผิดท่า: ต้องยืนเท่านั้น';
      });
      _speakWarning('ทำผิดท่าค่ะ ต้องยืนขึ้นเพื่อทำท่านี้ ห้ามนั่งทำนะคะ');
      return;
    }

    bool isCorrectLegAbducted = currentLeg == 'ซ้าย'
        ? _isLeftLegAbducted()
        : _isRightLegAbducted();

    if (isCorrectLegAbducted) {
      _startHoldTimer();
    } else {
      bool isWrongLegAbducted = currentLeg == 'ซ้าย'
          ? _isRightLegAbducted()
          : _isLeftLegAbducted();

      if (isWrongLegAbducted) {
        _stopHoldTimer();
        setState(() {
          feedbackMessage = 'ทำขาผิดข้าง! ตอนนี้ต้องทำขา $currentLeg';
          warningMessage = 'ทำผิดข้าง! กรุณาสลับมาทำขา $currentLeg';
        });
        _speakWarning(
          'ทำขาผิดข้างค่ะ ตอนนี้ต้องทำขา $currentLeg ค่ะ กรุณาสลับข้างด้วยนะคะ',
        );
      } else {
        _stopHoldTimer();
        setState(() {
          feedbackMessage = 'กำลังทำท่า: $exerciseName (ขา$currentLeg)';
          warningMessage = 'ค่อยๆ ยกขา $currentLeg ออกด้านข้าง';
        });
      }
    }
  }

  void _speakWarning(String message) {
    final now = DateTime.now();
    if (_lastWarningTime == null ||
        now.difference(_lastWarningTime!).inSeconds >= 6) {
      _lastWarningTime = now;
      _speak(message, force: true);
    }
  }

  void _startHoldTimer() {
    if (_isHoldingCorrectPose) return;

    _isHoldingCorrectPose = true;
    _holdSeconds = 0;
    _holdTimer?.cancel();

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _holdTimer = null;
        return;
      }

      String exerciseName = prescription.exerciseName;
      bool stillValid =
          _isStandingPosture() &&
          (currentLeg == 'ซ้าย' ? _isLeftLegAbducted() : _isRightLegAbducted());

      if (!stillValid) {
        timer.cancel();
        _holdTimer = null;
        _isHoldingCorrectPose = false;
        _holdSeconds = 0;
        setState(() {
          feedbackMessage = 'ท่าหลุด! กรุณายกขา$currentLegค้างไว้ให้ถูกต้อง';
          warningMessage = 'ทำผิดท่าระหว่างค้างเวลา!';
        });
        return;
      }

      _holdSeconds++;
      if (_holdSeconds <= holdTargetSeconds) {
        _speak('$_holdSeconds', force: true);
      }

      setState(() {
        feedbackMessage =
            'กำลังทำท่า: ${prescription.exerciseName} (ขา$currentLeg)\nท่าถูกต้อง ค้างไว้ $_holdSeconds / $holdTargetSeconds วินาที';
        warningMessage = '';
      });

      if (_holdSeconds >= holdTargetSeconds) {
        timer.cancel();
        _holdTimer = null;

        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          _isHoldingCorrectPose = false;
          _completeOneRep();
        });
      }
    });
  }

  void _stopHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _isHoldingCorrectPose = false;
    _holdSeconds = 0;
  }

  void _completeOneRep() {
    if (!mounted || _exerciseCompleted) return;
    currentRep++;

    String exerciseName = prescription.exerciseName;

    if (currentRep < targetRep) {
      currentLeg = currentLeg == 'ซ้าย' ? 'ขวา' : 'ซ้าย';
      String legName = currentLeg;

      _isResting = true;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          _isResting = false;
          feedbackMessage = 'สลับมาทำขา$legNameแล้ว';
          warningMessage = 'เตรียมพร้อมทำท่า $exerciseName ต่อ';
        });
        _speak('สลับมาทำขา $legName ในท่า $exerciseName ต่อค่ะ', force: true);
      });
      return;
    }

    currentRep = 0;
    setState(() {
      feedbackMessage = 'เยี่ยมมาก จบเซตท่า $exerciseName แล้วค่ะ';
      warningMessage = 'พักผ่อนสักครู่';
    });
    _completeSet();
  }

  void _completeSet() {
    _stopHoldTimer();
    completedSets++;

    String exerciseName = prescription.exerciseName;

    if (completedSets >= targetSet) {
      if (widget.onComplete != null) {
        _speak(
          'ยอดเยี่ยมมากค่ะ ทำท่านี้ครบแล้ว กำลังเปลี่ยนไปท่าถัดไปค่ะ',
          force: true,
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          widget.onComplete!();
        });
        return;
      }

      setState(() {
        _exerciseCompleted = true;
        _isResting = true;
        feedbackMessage = 'ออกกำลังกายครบทุกท่าของวันนี้แล้ว!';
        warningMessage = 'ทำครบทุกท่าแล้ว 🎉';
      });
      _speak('ยอดเยี่ยมมากค่ะ วันนี้ออกกำลังกายครบทุกท่าแล้วค่ะ', force: true);

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Chat()),
        );
      });
      return;
    }

    setState(() {
      _isResting = true;
      feedbackMessage =
          'พักผ่อนสักครู่ กำลังเริ่มเซตถัดไปของท่า $exerciseName...';
      warningMessage = '';
    });

    _speak('เยี่ยมมาก จบหนึ่งเซตแล้วค่ะ พักผ่อนสักครู่', force: true);

    Future.delayed(const Duration(seconds: 20), () {
      if (!mounted) return;
      setState(() {
        _isResting = false;
        currentRep = 0;
        currentLeg = 'ซ้าย';
        _holdSeconds = 0;
        _isHoldingCorrectPose = false;
        feedbackMessage =
            'เริ่มทำเซตต่อไปของท่า $exerciseName เริ่มจากขาซ้ายค่ะ';
        warningMessage = 'เตรียมพร้อม';
      });
      _speak(
        'พักผ่อนครบแล้ว เริ่มทำเซตต่อไปของท่า $exerciseName เริ่มจากขาซ้ายค่ะ',
        force: true,
      );
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
                                              : 'แจ้งเตือน: หันหน้าตรงเข้าหากล้อง',
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
                                          title: 'จำนวน',
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
                                          : 'กำลังฝึกขา$currentLeg',
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
