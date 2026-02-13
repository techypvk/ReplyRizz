import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reply_rizz/services/history_service.dart';
import 'package:reply_rizz/services/settings_service.dart';
import 'package:reply_rizz/services/reply_controller.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../theme/app_theme.dart';
import '../widgets/reply_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ResultSheet extends StatefulWidget {
  final String prompt;
  final String vibe;
  final List<String> replies; // Passed in for now, later fetched

  const ResultSheet({
    super.key,
    required this.prompt,
    required this.vibe,
    required this.replies,
  });

  @override
  State<ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<ResultSheet> {
  // Shake Detection Variables
  StreamSubscription? _accelerometerSubscription;
  static const double _shakeThreshold = 15.0; // Sensory threshold
  DateTime _lastShakeTime = DateTime.now();

  // State for regeneration
  late List<String> _currentReplies;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentReplies = widget.replies;
    _startShakeListening();

    // Check for one-time tooltip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsService>();
      if (settings.isMagicShakeEnabled && !settings.hasSeenShakeTooltip) {
        settings.markShakeTooltipSeen();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.vibration, color: AppTheme.background),
                SizedBox(width: 8),
                Expanded(
                  child: Text("Magic Shake enabled! Shake device to retry."),
                ),
              ],
            ),
            backgroundColor: AppTheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _startShakeListening() {
    final settings = context.read<SettingsService>();
    if (!settings.isMagicShakeEnabled) return;

    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      final double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // Check threshold and debounce
      if (acceleration > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime) > const Duration(seconds: 1)) {
          _lastShakeTime = now;
          _handleShake();
        }
      }
    });
  }

  void _handleShake() {
    if (!mounted) return;

    // Double check setting
    if (!context.read<SettingsService>().isMagicShakeEnabled) return;

    if (_isLoading) return; // Prevent shake while loading
    // Trigger regeneration instead of closing
    _regenerateReplies();
  }

  Future<void> _regenerateReplies() async {
    setState(() => _isLoading = true);

    try {
      final newReplies = await ReplyController.generate(
        context: context,
        text: widget.prompt,
        vibe: widget.vibe,
        isRegeneration: true,
      );

      if (newReplies == null) {
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        setState(() {
          _currentReplies = newReplies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleCopy(String reply) {
    if (!mounted) return;

    // Save to history
    context.read<HistoryService>().saveItem(widget.prompt, widget.vibe, [
      reply,
    ]);

    // Clipboard.setData handled in ReplyCard

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: AppTheme.background),
            SizedBox(width: 8),
            Text('Rizz copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HERE ARE YOUR OPTIONS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white54,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.vibe.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: min(
                      _currentReplies.length,
                      3,
                    ), // Limit to 3 cards
                    itemBuilder: (context, index) {
                      return ReplyCard(
                        text: _currentReplies[index],
                        index: index,
                        onTap: () => _handleCopy(_currentReplies[index]),
                      ).animate(delay: (100 * index).ms).fadeIn().slideX();
                    },
                  ),
          ),

          // Try Again Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _regenerateReplies,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: Colors.black),
                label: Text(
                  _isLoading ? "COOKING..." : "TRY AGAIN",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Shake Hint - Only show if enabled
          Consumer<SettingsService>(
            builder: (context, settings, _) {
              if (!settings.isMagicShakeEnabled) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.vibration,
                      color: Colors.white24,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Shake to retry works too!",
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white10);
      },
    );
  }
}
