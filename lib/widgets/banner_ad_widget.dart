import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../services/monetization_controller.dart';

class BannerAdWidget extends StatelessWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MonetizationController>(
      builder: (context, monetization, child) {
        final ad = monetization.loadedBannerAd;
        if (ad == null) {
          return const SizedBox.shrink();
        }

        return Container(
          alignment: Alignment.center,
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        );
      },
    );
  }
}
