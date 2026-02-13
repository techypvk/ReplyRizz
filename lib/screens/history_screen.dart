import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE VAULT',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.secondary,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'SAVED RIZZ',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 0.9,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),

            // List
            Expanded(
              child: Consumer<HistoryService>(
                builder: (context, history, child) {
                  if (history.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.history_toggle_off,
                            size: 60,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No Rizz stored yet.",
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(),
                    );
                  }

                  final groupedItems = <String, List<HistoryItem>>{};
                  for (var item in history.items) {
                    (groupedItems[item.vibe] ??= []).add(item);
                  }

                  // Sort: Favorites first, then by date descending
                  for (var key in groupedItems.keys) {
                    groupedItems[key]!.sort((a, b) {
                      if (a.isFavorite != b.isFavorite) {
                        return a.isFavorite ? -1 : 1;
                      }
                      return b.timestamp.compareTo(a.timestamp);
                    });
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 0,
                    ),
                    children: groupedItems.entries.map((entry) {
                      final vibe = entry.key;
                      final items = entry.value;

                      return Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          iconColor: AppTheme.primary,
                          collapsedIconColor: Colors.white54,
                          title: Text(
                            vibe.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          children: items.map((item) {
                            return Dismissible(
                              key: Key(item.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) {
                                history.deleteItem(item.id);
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                color: AppTheme.error,
                                padding: const EdgeInsets.only(right: 24),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.secondary
                                                .withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            item.vibe.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              color: AppTheme.secondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                item.isFavorite
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                size: 20,
                                                color: item.isFavorite
                                                    ? const Color(0xFFFFD700)
                                                    : Colors.white24,
                                              ),
                                              onPressed: () {
                                                history.toggleFavorite(item.id);
                                                HapticFeedback.selectionClick();
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              style: IconButton.styleFrom(
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              // Simple date formatter
                                              "${item.timestamp.month}/${item.timestamp.day}",
                                              style: const TextStyle(
                                                color: Colors.white24,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "PROMPT: ${item.prompt}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Divider(
                                      color: Colors.white10,
                                      height: 24,
                                    ),
                                    ...item.replies.map(
                                      (reply) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(
                                              ClipboardData(text: reply),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Copied!'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                            HapticFeedback.lightImpact();
                                          },
                                          onLongPress: () {
                                            Clipboard.setData(
                                              ClipboardData(text: reply),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Copied!'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                            HapticFeedback.mediumImpact();
                                          },
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.copy,
                                                size: 12,
                                                color: Colors.white24,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  reply,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn().slideX();
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
