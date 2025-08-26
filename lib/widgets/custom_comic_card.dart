import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:card_loading/card_loading.dart';
import 'package:nettruyen_reader/constants/app_constants.dart';
import 'package:nettruyen_reader/constants/theme_constants.dart';
import 'package:nettruyen_reader/models/comic.dart';
import 'package:nettruyen_reader/providers/font_provider.dart';
import 'package:provider/provider.dart';

class CustomComicCard extends StatelessWidget {
  final Comic comic;
  final VoidCallback? onTap;
  final String? domain;
  final bool showChapterBadge;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final BoxShadow? customShadow;
  final BorderRadius? customBorderRadius;
  final int columnCount; // Number of columns to determine text line limit

  const CustomComicCard({
    super.key,
    required this.comic,
    this.onTap,
    this.domain,
    this.showChapterBadge = true,
    this.width,
    this.height,
    this.margin,
    this.customShadow,
    this.customBorderRadius,
    this.columnCount = 1, // Default to 1 column (2 lines)
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: customBorderRadius ?? BorderRadius.circular(8),
        ),
        elevation: 0,
        margin: margin,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: customBorderRadius ?? BorderRadius.circular(8),
            border: Border.all(
              color: Colors.black,
              width: 2.0,
            ),
            boxShadow: [
              customShadow ??
                  const BoxShadow(
                    color: Colors.black,
                    offset: Offset(4, 4),
                    blurRadius: 0, // No blur
                    spreadRadius: 0, // No spread
                  ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image container that takes 85% of card height
              Flexible(
                flex: 17,
                child: Stack(
                  children: [
                    // Main image with fixed dimensions
                    Hero(
                      tag: comic.imageUrl,
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                            (customBorderRadius?.topLeft.x ?? 6) - 2,
                          ),
                        ),
                        child: _buildImage(context),
                      ),
                    ),
                    // Chapter number badge on top left (shows Ch. prefix)
                    if (showChapterBadge && comic.chapterCount != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildChapterBadge(comic.chapterCount!, context),
                      ),
                  ],
                ),
              ),
              // Text section that takes 15% of card height
              Flexible(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? ThemeConstants.netflixDarkGray // ← Dark theme: Dark grey background
                        : Colors.grey[100], // ← Light theme: Light grey background
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(
                        (customBorderRadius?.bottomLeft.x ?? 6) - 2,
                      ), // ← Bottom left corner
                      bottomRight: Radius.circular(
                        (customBorderRadius?.bottomRight.x ?? 6) - 2,
                      ), // ← Bottom right corner
                    ),
                  ),
                  child: Center(
                    child: Consumer<FontProvider>(
                      builder: (context, fontProvider, child) {
                        return Text(
                          _cleanTitle(comic.title),
                          style: fontProvider.getScaledTextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: columnCount == 1 ? 2 : 1, // 1 column = 2 lines, 2-3 columns = 1 line
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (domain != null) {
      return _buildCachedImage(context, domain!);
    }

    // If no domain provided, show shimmer loading
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[700],
      child: CardLoading(
        height: double.infinity,
        width: double.infinity,
      ),
    );
  }

  Widget _buildCachedImage(BuildContext context, String domain) {
    return CachedNetworkImage(
      cacheManager: CacheManager(
        Config(AppConstants.THUMB_CACHE_KEY),
      ),
      imageUrl: comic.imageUrl,
      httpHeaders: {'Referer': domain},
      imageBuilder: (ctx, provider) {
        return Image(
          image: provider,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
      placeholder: (ctx, url) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[700],
          child: CardLoading(
            height: double.infinity,
            width: double.infinity,
          ),
        );
      },
      errorWidget: (ctx, url, error) {
        // Show error state since broken comics should be filtered out at data level
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[700],
          child: const Center(
            child: Icon(
              Icons.broken_image,
              size: 40,
            ),
          ),
        );
      },
    );
  }

  /// Build chapter badge with rainbow effect for high chapter counts
  Widget _buildChapterBadge(int chapterCount, BuildContext context) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        final isHighChapter = chapterCount > 500;
        
        Widget badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isHighChapter 
                ? Colors.purple.withValues(alpha: 0.9) 
                : Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Ch.$chapterCount',
            style: fontProvider.getScaledTextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

        // Apply rainbow shimmer effect for high chapter counts
        if (isHighChapter) {
          badge = badge.animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 2000.ms, color: Colors.red, size: 2.0)
              .then()


               
              .shimmer(duration: 2000.ms, color: Colors.blue, size: 2.0)
              .then()
              .shimmer(duration: 2000.ms, color: Colors.purple, size: 2.0);
        }

        return Stack(
          children: [
            badge,
            Positioned.fill(
              child: Center(
                child: Text(
                  'Ch.$chapterCount',
                  style: fontProvider.getScaledTextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Clean comic title by removing common prefixes
  String _cleanTitle(String title) {
    // Remove common prefixes and clean up the title
    return title
        .replaceFirst(RegExp(r'^[Tt]ruyện tranh\s*'), '') // Remove "Truyện tranh" prefix
        .replaceAll(RegExp(r'^\[.*?\]\s*'), '') // Remove [brackets] at start
        .replaceAll(RegExp(r'^\d+\.\s*'), '') // Remove "1. " at start
        .trim();
  }
}
