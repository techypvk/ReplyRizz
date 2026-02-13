import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reply_rizz/services/monetization_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonetizationController Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial values are correct', () async {
      final controller = MonetizationController();
      // Wait for _loadFromPrefs to complete (it's called in constructor)
      await Future.delayed(Duration(milliseconds: 100));

      expect(controller.freeRepliesUsed, 0);
      expect(controller.rewardedCredits, 0);
      expect(controller.isInterstitialAdLoaded, isFalse);
      expect(controller.isRewardedAdLoaded, isFalse);
    });

    test('Increment free replies works', () async {
      final controller = MonetizationController();
      await Future.delayed(Duration(milliseconds: 100));

      controller.incrementFreeRepliesUsed();
      expect(controller.freeRepliesUsed, 1);
    });

    test('Add rewarded credits works', () async {
      final controller = MonetizationController();
      await Future.delayed(Duration(milliseconds: 100));

      controller.addRewardedCredits(5);
      expect(controller.rewardedCredits, 5);
    });

    test('Consume credit works', () async {
      final controller = MonetizationController();
      await Future.delayed(Duration(milliseconds: 100));

      controller.addRewardedCredits(1);
      // Exhaust free replies first for this test
      for (int i = 0; i < MonetizationController.maxFreeRepliesPerCycle; i++) {
        controller.useReply();
      }

      final success = controller.useReply();

      expect(success, true);
      expect(controller.rewardedCredits, 0);

      final fail = controller.useReply();
      expect(fail, false);
    });

    test('Reset free replies works', () async {
      final controller = MonetizationController();
      await Future.delayed(Duration(milliseconds: 100));

      controller.incrementFreeRepliesUsed();
      controller.resetFreeReplies();
      expect(controller.freeRepliesUsed, 0);
    });
  });
}
