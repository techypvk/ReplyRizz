import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';

class ShakeDetector {
  final VoidCallback onPhoneShake;
  final double shakeThresholdGravity;
  final int shakeSlopTimeMS;
  final int shakeCountResetTime;
  final int minimumShakeCount;

  int _shakeCount = 0;
  DateTime _lastShakeTimestamp = DateTime.now();
  StreamSubscription? _streamSubscription;

  ShakeDetector.autoStart({
    required this.onPhoneShake,
    this.shakeThresholdGravity = 2.7,
    this.shakeSlopTimeMS = 500,
    this.shakeCountResetTime = 3000,
    this.minimumShakeCount = 1,
  }) {
    startListening();
  }

  void startListening() {
    _streamSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      final double gX = event.x / 9.80665;
      final double gY = event.y / 9.80665;
      final double gZ = event.z / 9.80665;

      // gForce will be close to 1 when there is no movement.
      double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      if (gForce > shakeThresholdGravity) {
        final now = DateTime.now();
        // Ignore shakes too close to each other (debounce)
        if (_lastShakeTimestamp.difference(now).inMilliseconds.abs() >
            shakeSlopTimeMS) {
          _shakeCount++;
          _lastShakeTimestamp = now;

          if (_shakeCount >= minimumShakeCount) {
            _shakeCount = 0;
            onPhoneShake();
          }
        }
      }
    });
  }

  void stopListening() {
    _streamSubscription?.cancel();
  }
}
