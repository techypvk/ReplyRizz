import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ai_service.dart';
import 'history_service.dart';
import 'monetization_controller.dart';
import '../theme/app_theme.dart';

class ReplyController {
  /// The main controller function for reply generation.
  ///
  /// Responsibilities:
  /// - Enforce reply limits
  /// - Decide when to show interstitial ads
  /// - Decide when to consume reward credits
  /// - Call the AI reply generation only when allowed
  /// - Ensure ads never block reply generation permanently
  static Future<List<String>?> generate({
    required BuildContext context,
    required String text,
    required String vibe,
    Uint8List? imageBytes,
    bool isRegeneration = false,
  }) async {
    final monetization = context.read<MonetizationController>();
    final aiService = context.read<AIService>();
    final historyService = context.read<HistoryService>();

    // 1. Decide if we should show an interstitial ad
    if (monetization.shouldShowInterstitial) {
      bool adDismissed = false;
      await monetization.showInterstitialAd(
        onDismissed: () {
          adDismissed = true;
        },
      );

      // If ad was shown (or attempted), we continue with generation
      // The monetization.showInterstitialAd handles the counter reset internally
      if (adDismissed) {
        // Recursively call generate after ad dismissal
        return generate(
          context: context,
          text: text,
          vibe: vibe,
          imageBytes: imageBytes,
          isRegeneration: isRegeneration,
        );
      }
    }

    // 2. Check if we can use a reply (exhausts free or uses credit)
    if (!monetization.useReply()) {
      // Out of replies, show rewarded ad dialog
      if (context.mounted) {
        final bool? rewarded = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text(
              'OUT OF REPLIES',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Watch a short ad to get 3 more rizz credits and generate your reply!',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              Consumer<MonetizationController>(
                builder: (context, monetization, _) {
                  final isLoaded = monetization.isRewardedAdLoaded;
                  final isLoading = monetization.isRewardedLoading;

                  return ElevatedButton.icon(
                    onPressed: isLoaded
                        ? () {
                            // Show the rewarded ad
                            Navigator.pop(context, true);
                          }
                        : null,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : const Icon(Icons.play_circle_fill),
                    label: Text(
                      isLoading
                          ? 'LOADING...'
                          : isLoaded
                          ? 'WATCH AD (+3)'
                          : 'AD NOT READY',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLoaded
                          ? AppTheme.primary
                          : Colors.grey,
                      foregroundColor: Colors.black,
                    ),
                  );
                },
              ),
            ],
          ),
        );

        if (rewarded == true) {
          bool rewardEarned = false;
          await monetization.showRewardedAd(
            onRewardEarned: () {
              rewardEarned = true;
            },
          );

          if (rewardEarned) {
            // Auto-retry generation after earning reward
            return generate(
              context: context,
              text: text,
              vibe: vibe,
              imageBytes: imageBytes,
              isRegeneration: isRegeneration,
            );
          }
        }
      }
      return null; // Generation cancelled or failed to get credits
    }

    // 3. Call the AI reply generation
    try {
      final replies = await aiService.generateReplies(
        text,
        vibe,
        imageBytes: imageBytes,
      );

      // 4. Save to history
      final historyText = imageBytes != null ? "[Image Upload] $text" : text;
      await historyService.saveItem(historyText, vibe, replies);

      return replies;
    } catch (e) {
      // Re-throw or handle AI errors
      rethrow;
    }
  }
}
