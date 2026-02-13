import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../theme/app_theme.dart';
import '../widgets/vibe_chip.dart';

import '../widgets/scale_button.dart';
import '../services/monetization_controller.dart';
import '../services/reply_controller.dart';
import '../services/settings_service.dart';
import 'result_sheet.dart';
import 'history_screen.dart';
import '../widgets/banner_ad_widget.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GeneratorView(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          const BannerAdWidget(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: AppTheme.background,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.white24,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt_rounded),
            label: 'Generate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class GeneratorView extends StatefulWidget {
  const GeneratorView({super.key});

  @override
  State<GeneratorView> createState() => _GeneratorViewState();
}

class _GeneratorViewState extends State<GeneratorView> {
  final TextEditingController _textController = TextEditingController();
  final ValueNotifier<String> _selectedVibe = ValueNotifier('Witty');
  bool _isLoading = false;

  // Shake
  StreamSubscription? _accelerometerSubscription;
  DateTime _lastShakeTime = DateTime.now();
  static const double _shakeThreshold = 15.0;

  final List<Map<String, String>> _vibes = const [
    {'label': 'Witty', 'emoji': '🧠'},
    {'label': 'Flirty', 'emoji': '😏'},
    {'label': 'Lovely', 'emoji': '🥰'},
    {'label': 'Cold', 'emoji': '❄️'},
    {'label': 'Professional', 'emoji': '💼'},
    {'label': 'Friendly', 'emoji': '👋'},
    {'label': 'Savage', 'emoji': '🔥'},
  ];

  @override
  void initState() {
    super.initState();
    _initShakeDetection();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _textController.dispose();
    _selectedVibe.dispose();
    super.dispose();
  }

  void _initShakeDetection() {
    // Start listening directly
    _accelerometerSubscription = accelerometerEvents.listen((
      AccelerometerEvent event,
    ) {
      if (!mounted) return;
      // Check settings dynamically
      final settings = Provider.of<SettingsService>(context, listen: false);
      if (!settings.isMagicShakeEnabled) return;

      final now = DateTime.now();
      if (now.difference(_lastShakeTime).inMilliseconds < 1500) {
        return; // Debounce 1.5s
      }

      if (event.x.abs() > _shakeThreshold ||
          event.y.abs() > _shakeThreshold ||
          event.z.abs() > _shakeThreshold) {
        _lastShakeTime = now;

        // Trigger generation if not loading and has text
        if (!_isLoading && _textController.text.trim().isNotEmpty) {
          debugPrint("Shake Triggered!");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✨ Magic Shake Activated!"),
              duration: Duration(milliseconds: 1000),
            ),
          );
          _generateRizz();
        } else if (_textController.text.isEmpty) {
          // Maybe just random vibe shake? Or instruct user?
          // User req: "Instant Rizz generation OR Try Again with same input"
          // If empty, can't generate.
        }
      }
    });
  }

  bool _isContentSafe(String text) {
    // Basic local filter for safety compliance
    final lowerText = text.toLowerCase();
    final forbiddenKeywords = [
      'hate',
      'kill',
      'murder',
      'attack',
      'stupid',
      'idiot',
      'sex',
      'nude',
      'naked',
      'xxx',
      'porn',
      'suicide',
      'die',
      'ashhole',
      'bitch',
    ];

    for (final word in forbiddenKeywords) {
      if (lowerText.contains(word)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _generateRizz() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (text.length > 280) return;

    if (!_isContentSafe(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Safety Filter: content not suitable for generation.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vibe = _selectedVibe.value;
      final replies = await ReplyController.generate(
        context: context,
        text: text,
        vibe: vibe,
      );

      if (replies == null) {
        // Generation was cancelled or no credits available
        return;
      }

      if (!mounted) return;

      // Show Result Sheet
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            ResultSheet(prompt: text, vibe: vibe, replies: replies),
      );

      // If returned true (shaken/reset), clear input.
      // Note: User constraint says "Try Again with same input" on shake.
      // So maybe we don't clear?
      // Existing logic clears on result == true.
      if (result == true) {
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset! Ready for next round.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $errorMessage')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WHO ARE WE',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppTheme.primary,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              Text(
                                'TEXTING?',
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      height: 0.9,
                                    ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Consumer<MonetizationController>(
                                builder: (context, monetization, _) {
                                  final isAdLoaded =
                                      monetization.isRewardedAdLoaded;
                                  return TextButton.icon(
                                    onPressed: isAdLoaded
                                        ? () {
                                            monetization.showRewardedAd(
                                              onRewardEarned: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Reward Earned! +1 Extra Reply ✨',
                                                    ),
                                                    backgroundColor:
                                                        AppTheme.primary,
                                                  ),
                                                );
                                              },
                                              onDismissed: () {},
                                            );
                                          }
                                        : null,
                                    icon: Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 18,
                                      color: isAdLoaded
                                          ? AppTheme.primary
                                          : Colors.white12,
                                    ),
                                    label: Text(
                                      monetization.isRewardedLoading
                                          ? 'LOADING...'
                                          : 'GET EXTRA REPLIES',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        color: isAdLoaded
                                            ? AppTheme.primary
                                            : Colors.white38,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      backgroundColor: isAdLoaded
                                          ? AppTheme.primary.withOpacity(0.1)
                                          : Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: isAdLoaded
                                              ? AppTheme.primary.withOpacity(
                                                  0.3,
                                                )
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: -0.2, end: 0),

                    // Input Field
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          controller: _textController,
                          maxLength: 280,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          maxLines: 10,
                          minLines: 5,
                          style: const TextStyle(fontSize: 18, height: 1.5),
                          decoration: InputDecoration(
                            hintText: "Paste their text here...",
                            hintStyle: const TextStyle(
                              color: Colors.white24,
                              fontSize: 18,
                            ),
                            filled: true,
                            fillColor: AppTheme.surface,
                            suffixIcon: IconButton(
                              padding: const EdgeInsets.only(right: 12),
                              icon: const Icon(
                                Icons.content_paste_rounded,
                                color: Colors.white54,
                              ),
                              onPressed: () async {
                                final data = await Clipboard.getData(
                                  Clipboard.kTextPlain,
                                );
                                if (data?.text != null) {
                                  _textController.text = data!.text!;
                                }
                              },
                              tooltip: 'Paste',
                            ),
                          ),
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) {
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Short messages work best...",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                    ),
                                    Text(
                                      "$currentLength/$maxLength",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                );
                              },
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    // Vibe Selector
                    Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'CHOOSE THE VIBE',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Colors.white54,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: ValueListenableBuilder<String>(
                                  valueListenable: _selectedVibe,
                                  builder: (context, currentVibe, _) {
                                    return Row(
                                      children: _vibes.map((vibe) {
                                        return VibeChip(
                                          label: vibe['label']!,
                                          emoji: vibe['emoji']!,
                                          isSelected:
                                              currentVibe == vibe['label'],
                                          onTap: () => _selectedVibe.value =
                                              vibe['label']!,
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 400.ms)
                        .slideY(begin: 0.2, end: 0),

                    // Generate Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _textController,
                        builder: (context, value, _) {
                          final isEnabled =
                              !_isLoading && value.text.trim().isNotEmpty;
                          return SizedBox(
                            width: double.infinity,
                            child: ScaleButton(
                              onPressed: isEnabled ? _generateRizz : null,
                              child: Container(
                                alignment: Alignment.center,
                                height: 56, // Standard button height
                                decoration: BoxDecoration(
                                  color: isEnabled
                                      ? AppTheme.primary
                                      : AppTheme.primary.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // Assuming standard radius
                                  boxShadow: isEnabled
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primary.withOpacity(
                                              0.5,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'GENERATE RIZZ ✨',
                                        style: TextStyle(
                                          color: Colors
                                              .black, // Assuming primary contrast
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ).animate().scale(delay: 600.ms),

                    // Disclaimer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Text(
                        "AI-generated replies may not always be appropriate. Use responsibly.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
