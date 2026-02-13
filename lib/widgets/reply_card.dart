import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ReplyCard extends StatelessWidget {
  final String text;
  final int index;
  final VoidCallback onTap;

  const ReplyCard({
    super.key,
    required this.text,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Haptic Feedback
            await HapticFeedback.mediumImpact();

            // Copy to Clipboard
            await Clipboard.setData(ClipboardData(text: text));

            // Trigger parent callback (e.g. for analytics or toast)
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Numbering
                Text(
                  '0${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white24,
                    fontFamily: 'Courier', // Monospace for style
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1), // Neon lime tint
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
