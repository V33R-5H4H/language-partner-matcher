import 'package:flutter/material.dart';

enum CallStatus { idle, connecting, connected, ended }

class CallProvider extends ChangeNotifier {
  CallStatus _status = CallStatus.idle;
  bool _isMicMuted = false;
  bool _isVideoOff = false;
  bool _isFrontCamera = true;
  int _callDurationSeconds = 0;

  CallStatus get status => _status;
  bool get isMicMuted => _isMicMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isFrontCamera => _isFrontCamera;
  int get callDurationSeconds => _callDurationSeconds;

  void setCallStatus(CallStatus status) {
    _status = status;
    notifyListeners();
  }

  void toggleMic() {
    _isMicMuted = !_isMicMuted;
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoOff = !_isVideoOff;
    notifyListeners();
  }

  void switchCamera() {
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  void reset() {
    _status = CallStatus.idle;
    _isMicMuted = false;
    _isVideoOff = false;
    _callDurationSeconds = 0;
    notifyListeners();
  }
}
