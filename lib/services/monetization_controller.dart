import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class MonetizationController extends ChangeNotifier {
  static const String _keyFreeRepliesUsed = 'free_replies_used';
  static const String _keyRewardedCredits = 'rewarded_credits';
  static const String _keyLastResetTime = 'last_reset_time';

  // Ad Unit IDs (TEST)
  static final String _interstitialAdUnitId = kIsWeb
      ? ''
      : defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  static final String _rewardedAdUnitId = kIsWeb
      ? ''
      : defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  static final String _bannerAdUnitId = kIsWeb
      ? ''
      : defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  // Configuration
  static const int maxFreeRepliesPerCycle = 3;
  static const Duration cycleDuration = Duration(hours: 24);
  static const int _maxRetryAttempts = 5;

  int _freeRepliesUsed = 0;
  int _rewardedCredits = 0;
  DateTime _lastResetTime = DateTime.now();
  int _interstitialRetryAttempt = 0;
  int _rewardedRetryAttempt = 0;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  InterstitialAd? _loadedInterstitialAd;
  RewardedAd? _loadedRewardedAd;
  BannerAd? _loadedBannerAd;

  bool get isInterstitialLoading => _isInterstitialLoading;
  bool get isRewardedLoading => _isRewardedLoading;
  bool get isInterstitialAdLoaded => _loadedInterstitialAd != null;
  bool get isRewardedAdLoaded => _loadedRewardedAd != null;

  int get freeRepliesUsed => _freeRepliesUsed;
  int get rewardedCredits => _rewardedCredits;

  InterstitialAd? get loadedInterstitialAd => _loadedInterstitialAd;
  RewardedAd? get loadedRewardedAd => _loadedRewardedAd;
  BannerAd? get loadedBannerAd => _loadedBannerAd;

  int get remainingFreeReplies {
    final remaining = maxFreeRepliesPerCycle - _freeRepliesUsed;
    return remaining > 0 ? remaining : 0;
  }

  bool get shouldShowInterstitial {
    // Show interstitial on the 4th reply attempt (when free replies are exhausted)
    // and if we have an ad loaded.
    // Rule: "On the 4th reply attempt, show an interstitial ad"
    // Rule: "Never show interstitial during rewarded reply usage"
    // Rule: "Rewarded replies must never trigger interstitial ads"
    return _freeRepliesUsed >= maxFreeRepliesPerCycle &&
        _rewardedCredits == 0 &&
        _loadedInterstitialAd != null;
  }

  MonetizationController() {
    _init();
  }

  Future<void> _init() async {
    await _loadFromPrefs();
    checkAndResetCycle();

    // Initialize MobileAds and load ads in background
    _initializeAdMobAndLoadAds();
  }

  Future<void> _initializeAdMobAndLoadAds() async {
    try {
      await MobileAds.instance.initialize();
      debugPrint('AdMob Initialized.');

      _loadInterstitialAd(); // Preload on app launch
      _loadRewardedAd(); // Preload on app launch
      _loadBannerAd(); // Preload on app launch
    } catch (e) {
      debugPrint('Error initializing AdMob: $e');
    }
  }

  void _loadInterstitialAd() {
    if (_isInterstitialLoading || _loadedInterstitialAd != null) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('InterstitialAd loaded.');
          _loadedInterstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialRetryAttempt = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('InterstitialAd dismissed.');
              ad.dispose();
              _loadedInterstitialAd = null;
              _loadInterstitialAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('InterstitialAd failed to show: $error');
              ad.dispose();
              _loadedInterstitialAd = null;
              _loadInterstitialAd(); // Try loading again
            },
          );

          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isInterstitialLoading = false;
          _loadedInterstitialAd = null;

          // Retry logic
          if (_interstitialRetryAttempt < _maxRetryAttempts) {
            _interstitialRetryAttempt++;
            final delay = Duration(seconds: _interstitialRetryAttempt * 5);
            debugPrint(
              'Retrying interstitial load in ${delay.inSeconds}s (Attempt $_interstitialRetryAttempt)',
            );
            Future.delayed(delay, _loadInterstitialAd);
          }
        },
      ),
    );
  }

  void _loadRewardedAd() {
    if (_isRewardedLoading || _loadedRewardedAd != null) return;

    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('RewardedAd loaded.');
          _loadedRewardedAd = ad;
          _isRewardedLoading = false;
          _rewardedRetryAttempt = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('RewardedAd dismissed.');
              ad.dispose();
              _loadedRewardedAd = null;
              _loadRewardedAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('RewardedAd failed to show: $error');
              ad.dispose();
              _loadedRewardedAd = null;
              _loadRewardedAd(); // Try loading again
            },
          );

          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _isRewardedLoading = false;
          _loadedRewardedAd = null;

          // Retry logic
          if (_rewardedRetryAttempt < _maxRetryAttempts) {
            _rewardedRetryAttempt++;
            final delay = Duration(seconds: _rewardedRetryAttempt * 5);
            debugPrint(
              'Retrying rewarded load in ${delay.inSeconds}s (Attempt $_rewardedRetryAttempt)',
            );
            Future.delayed(delay, _loadRewardedAd);
          }
        },
      ),
    );
  }

  void _loadBannerAd() {
    if (_loadedBannerAd != null) return;

    _loadedBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('BannerAd loaded.');
          notifyListeners();
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
          _loadedBannerAd = null;
          // Retry banner load after a delay
          Future.delayed(const Duration(seconds: 30), _loadBannerAd);
        },
      ),
    )..load();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _freeRepliesUsed = prefs.getInt(_keyFreeRepliesUsed) ?? 0;
    _rewardedCredits = prefs.getInt(_keyRewardedCredits) ?? 0;

    final lastResetMs = prefs.getInt(_keyLastResetTime);
    if (lastResetMs != null) {
      _lastResetTime = DateTime.fromMillisecondsSinceEpoch(lastResetMs);
    } else {
      _lastResetTime = DateTime.now();
      await _saveLastResetToPrefs();
    }
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFreeRepliesUsed, _freeRepliesUsed);
    await prefs.setInt(_keyRewardedCredits, _rewardedCredits);
  }

  Future<void> _saveLastResetToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyLastResetTime,
      _lastResetTime.millisecondsSinceEpoch,
    );
  }

  /// Checks if the current cycle has expired and resets free replies if needed.
  void checkAndResetCycle() {
    final now = DateTime.now();
    // Check if the day has changed (midnight reset)
    final isNewDay =
        now.year != _lastResetTime.year ||
        now.month != _lastResetTime.month ||
        now.day != _lastResetTime.day;

    if (isNewDay) {
      _freeRepliesUsed = 0;
      _lastResetTime = now;
      _saveToPrefs();
      _saveLastResetToPrefs();
      notifyListeners();
    }
  }

  Future<void> showInterstitialAd({required VoidCallback onDismissed}) async {
    if (_loadedInterstitialAd == null) {
      onDismissed();
      return;
    }

    // Set up callbacks again to ensure the UI callback is called
    _loadedInterstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            debugPrint('InterstitialAd dismissed.');
            ad.dispose();
            _loadedInterstitialAd = null;
            _loadInterstitialAd(); // Load next ad
            resetFreeReplies(); // Reset counter after interstitial
            onDismissed();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint('InterstitialAd failed to show: $error');
            ad.dispose();
            _loadedInterstitialAd = null;
            _loadInterstitialAd(); // Try loading again
            onDismissed(); // Allow usage even if ad fails to show
          },
        );

    await _loadedInterstitialAd!.show();
  }

  Future<void> showRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onDismissed,
  }) async {
    if (_loadedRewardedAd == null) {
      onDismissed?.call();
      return;
    }

    _loadedRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('RewardedAd dismissed.');
        ad.dispose();
        _loadedRewardedAd = null;
        _loadRewardedAd(); // Load next ad
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('RewardedAd failed to show: $error');
        ad.dispose();
        _loadedRewardedAd = null;
        _loadRewardedAd(); // Try loading again
        onDismissed?.call();
      },
    );

    await _loadedRewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        addRewardedCredits(3); // Rule: +3 credits
        onRewardEarned();
      },
    );
  }

  // State update methods
  void incrementFreeRepliesUsed() {
    checkAndResetCycle(); // Ensure we are in the correct cycle
    _freeRepliesUsed++;
    _saveToPrefs();
    notifyListeners();
  }

  void addRewardedCredits(int amount) {
    _rewardedCredits += amount;
    _saveToPrefs();
    notifyListeners();
  }

  bool useReply() {
    // Rule: "If rewarded reply credits are available, consume them first"
    if (_rewardedCredits > 0) {
      _rewardedCredits--;
      _saveToPrefs();
      notifyListeners();
      return true;
    }

    // Rule: "If no reward credits, allow up to 3 free replies"
    checkAndResetCycle();
    if (_freeRepliesUsed < maxFreeRepliesPerCycle) {
      incrementFreeRepliesUsed();
      return true;
    }

    return false;
  }

  void resetFreeReplies() {
    _freeRepliesUsed = 0;
    _lastResetTime = DateTime.now();
    _saveToPrefs();
    _saveLastResetToPrefs();
    notifyListeners();
  }

  // Ad instance management
  void setInterstitialAd(InterstitialAd? ad) {
    if (_loadedInterstitialAd != ad) {
      _loadedInterstitialAd?.dispose();
      _loadedInterstitialAd = ad;
      notifyListeners();
    }
  }

  void setRewardedAd(RewardedAd? ad) {
    _loadedRewardedAd?.dispose();
    _loadedRewardedAd = ad;
    notifyListeners();
  }

  void setBannerAd(BannerAd? ad) {
    _loadedBannerAd?.dispose();
    _loadedBannerAd = ad;
    notifyListeners();
  }

  @override
  void dispose() {
    _loadedInterstitialAd?.dispose();
    _loadedRewardedAd?.dispose();
    _loadedBannerAd?.dispose();
    super.dispose();
  }
}
