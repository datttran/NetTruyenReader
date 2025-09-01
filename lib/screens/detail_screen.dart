// lib/screens/detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:typed_data';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../services/mangadex_service.dart';
import '../services/database_helper.dart';
import '../constants/theme_constants.dart';
import '../constants/app_constants.dart';
import '../widgets/mangadex_shimmer_loading.dart';
import '../widgets/full_screen_shimmer.dart';
import 'reader_screen.dart';
import 'genre_comics_screen.dart';

class _ImageResult {
  final bool isCached;
  final bool isHq;
  final String imageUrl;
  final Uint8List? cachedImage;

  const _ImageResult({
    required this.isCached,
    required this.isHq,
    required this.imageUrl,
    this.cachedImage,
  });
}

class DetailScreen extends StatefulWidget {
  final Comic comic;
  const DetailScreen({Key? key, required this.comic}) : super(key: key);

  @override
  DetailScreenState createState() => DetailScreenState();
}

class DetailScreenState extends State<DetailScreen> {
  late Future<Comic> _comicFuture;
  late Future<List<String>> _chaptersFuture;
  // MangaDex image loading
  late Future<_ImageResult> _imageFuture;
  late Future<Uint8List?> _downloadFuture;
  final CacheManager _thumbCache =
      CacheManager(Config(AppConstants.THUMB_CACHE_KEY));

  // Reading progress tracking
  Map<String, dynamic>? _readingProgress;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Domain management
  String? _lastUsedDomain;
  // New state variables for "See More" functionality
  List<String> _allChapters = [];
  bool _isLoadingMore = false;
  bool _hasMoreChapters = true;
  int _currentOffset = 0;
  static const int _chaptersPerBatch = 50;

  @override
  void initState() {
    super.initState();
    _comicFuture = _loadComicData();
    _chaptersFuture = _loadChapters();
    _imageFuture = _loadImage();
    _loadReadingProgress();
  }

  // Load reading progress for this comic
  Future<void> _loadReadingProgress() async {
    try {
      final progress =
          await _databaseHelper.getReadingProgress(widget.comic.detailUrl);
      setState(() {
        _readingProgress = progress;
      });
      print('🔍 DetailScreen: Reading progress loaded: $_readingProgress');
    } catch (e) {
      print('❌ DetailScreen: Error loading reading progress: $e');
    }
  }

  // Save reading progress when a chapter is opened
  Future<void> _saveReadingProgress(
      String chapterUrl, int chapterNumber) async {
    try {
      // Get the last available chapter number for completion calculation
      final chapters = _allChapters.isNotEmpty ? _allChapters : 
          (await _chaptersFuture);
      
      // Find the highest chapter number available
      int lastAvailableChapter = 0;
      for (final chapterUrl in chapters) {
        final chapterNum = _extractChapterNumber(chapterUrl);
        if (chapterNum > lastAvailableChapter) {
          lastAvailableChapter = chapterNum;
        }
      }
      
      // If we couldn't extract chapter numbers, fall back to total count
      if (lastAvailableChapter == 0) {
        lastAvailableChapter = chapters.length;
      }
      
      await _databaseHelper.saveReadingProgress(
        comicDetailUrl: widget.comic.detailUrl,
        chapterUrl: chapterUrl,
        chapterNumber: chapterNumber,
        lastAvailableChapter: lastAvailableChapter,
      );
      
      // Reload reading progress to update UI
      await _loadReadingProgress();
      print(
          '✅ DetailScreen: Reading progress saved for chapter $chapterNumber (${chapterNumber}/${lastAvailableChapter})');
    } catch (e) {
      print('❌ DetailScreen: Error saving reading progress: $e');
    }
  }

  // Format last read time for display
  String _formatLastReadTime(int timestamp) {
    final now = DateTime.now();
    final lastRead = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(lastRead);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  // Clear reading progress for this comic
  Future<void> _clearReadingProgress() async {
    try {
      await _databaseHelper.clearReadingProgress(widget.comic.detailUrl);
      setState(() {
        // Reset progress to 0% instead of null to keep widget visible
        _readingProgress = {
          'last_chapter_number': 0,
          'completion_percentage': 0.0,
          'last_read_at': null,
          'last_chapter_url': null,
          'current_page': null,
          'total_pages': null,
        };
      });
      print('✅ DetailScreen: Reading progress cleared');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa tiến độ đọc'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ DetailScreen: Error clearing reading progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa tiến độ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get rainbow color based on completion percentage
  Color _getRainbowColor(double percentage) {
    if (percentage < 25) {
      return Colors.red; // Red for low completion
    } else if (percentage < 50) {
      return Colors.orange; // Orange for quarter completion
    } else if (percentage < 75) {
      return Colors.yellow; // Yellow for half completion
    } else if (percentage < 100) {
      return Colors.green; // Green for near completion
    } else {
      return Colors.blue; // Blue for 100% completion
    }
  }

  // Get the last available chapter number for display
  int _getLastAvailableChapter() {
    final chapters = _allChapters.isNotEmpty ? _allChapters : [];
    if (chapters.isEmpty) return 0;
    
    int lastChapter = 0;
    for (final chapterUrl in chapters) {
      final chapterNum = _extractChapterNumber(chapterUrl);
      if (chapterNum > lastChapter) {
        lastChapter = chapterNum;
      }
    }
    
    // If we couldn't extract chapter numbers, fall back to total count
    return lastChapter > 0 ? lastChapter : chapters.length;
  }

  // Load comic data with details
  Future<Comic> _loadComicData() async {
    return await NetTruyenService().updateComicWithDetails(widget.comic);
  }

  // Load initial chapters
  Future<List<String>> _loadChapters() async {
    return await _loadInitialChapters();
  }

  /// Load initial chapters and set up state for "See More"
  Future<List<String>> _loadInitialChapters() async {
    try {
      final chapters =
          await NetTruyenService().fetchChapters(widget.comic.detailUrl);
      _allChapters = chapters;
      _currentOffset = chapters.length;

      // More lenient logic: show button if we have a reasonable number of chapters
      // This assumes most comics have more than what's visible in HTML
      _hasMoreChapters =
          chapters.length >= 10; // Show button for comics with 10+ chapters

      // Debug logging
      print('🔍 DetailScreen: Initial chapters loaded: ${chapters.length}');
      print('🔍 DetailScreen: _hasMoreChapters: $_hasMoreChapters');
      print('🔍 DetailScreen: _currentOffset: $_currentOffset');

      return chapters;
    } catch (e) {
      print('Error loading initial chapters: $e');
      return [];
    }
  }

  /// Load additional chapters when "See More" is clicked
  Future<void> _loadMoreChapters() async {
    if (_isLoadingMore || !_hasMoreChapters) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreChapters = await NetTruyenService().loadMoreChapters(
        widget.comic.detailUrl,
        offset: _currentOffset,
        limit: _chaptersPerBatch,
      );

      if (moreChapters.isNotEmpty) {
        setState(() {
          // Replace the current list with new API results
          // The API returns chapters from the beginning, so we replace entirely
          _allChapters = moreChapters;
          _currentOffset = moreChapters.length;
          _hasMoreChapters = moreChapters.length >= _chaptersPerBatch;
        });

        print(
            '🔍 DetailScreen: Replaced list with ${moreChapters.length} chapters from API');
      } else {
        setState(() {
          _hasMoreChapters = false;
        });
        print('🔍 DetailScreen: API returned no chapters, reached the end');
      }
    } catch (e) {
      print('Error loading more chapters: $e');
      // Could show error snackbar here
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// Load image with smart caching logic
  Future<_ImageResult> _loadImage() async {
    try {
      // Wait for comic data to be loaded first (this ensures we have fresh alternative names)
      final comic = await _comicFuture;
      print(
          '🔍 DetailScreen: _loadImage using fresh comic data with ${comic.alternativeNames.length} alternative names');

      // First, check if we have a cached MangaDex thumbnail
      if (await MangaDexService.hasCachedThumbnail(comic.detailUrl)) {
        final cache = await MangaDexService.getCachedThumbnail(comic.detailUrl);
        if (cache != null) {
          print('🔍 DetailScreen: ✅ Using cached MangaDex thumbnail');
          return _ImageResult(
              isCached: true, isHq: false, imageUrl: '', cachedImage: cache);
        }
      }

      // If no cache, try to get high-quality URL using fresh comic data
      final hqUrl = await _getHighQualityImageUrl(comic);
      if (hqUrl.isNotEmpty && hqUrl != comic.imageUrl) {
        print('🔍 DetailScreen: 📥 Found high-quality URL: $hqUrl');
        return _ImageResult(isCached: false, isHq: true, imageUrl: hqUrl);
      }

      // Fallback to original image
      print('🔍 DetailScreen: 🔄 Using original image');
      return _ImageResult(
          isCached: false, isHq: false, imageUrl: comic.imageUrl);
    } catch (e) {
      print('🔍 DetailScreen: ❌ Error in _loadImage: $e');
      return _ImageResult(
          isCached: false, isHq: false, imageUrl: widget.comic.imageUrl);
    }
  }

  /// Download and cache MangaDex image from URL
  Future<Uint8List?> _downloadAndCacheMangaDexImage(String mangadexUrl) async {
    try {
      print('🔍 DetailScreen: 📥 Downloading and caching MangaDex image');
      final downloadedImage = await MangaDexService.downloadMangaDexImage(
          mangadexUrl,
          comicUrl: widget.comic.detailUrl);

      if (downloadedImage != null) {
        print(
            '🔍 DetailScreen: ✅ Successfully downloaded and cached MangaDex image');
      } else {
        print('🔍 DetailScreen: ❌ Failed to download MangaDex image');
      }

      return downloadedImage;
    } catch (e) {
      print('🔍 DetailScreen: ❌ Error downloading MangaDex image: $e');
      return null;
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method gets the current domain for use in headers.
  /// It ensures that thumbnails are loaded with the correct Referer header.
  Future<String> _getCurrentDomainForHeaders() async {
    if (_lastUsedDomain != null) {
      return _lastUsedDomain!;
    }
    return AppConstants.PRIMARY_DOMAIN;
  }

  void _openReader(String chapterUrl) {
    print('🔍 DetailScreen: _openReader called with URL: $chapterUrl');

    // Extract chapter number for progress tracking
    final chapterNumber = _extractChapterNumber(chapterUrl);
    if (chapterNumber > 0) {
      _saveReadingProgress(chapterUrl, chapterNumber);
    }

    Navigator.push(
        context,
        MaterialPageRoute(
        builder: (context) => ReaderScreen(
          chapterUrl: chapterUrl,
        ),
      ),
    );
  }

  // Extract chapter number from chapter URL or title
  int _extractChapterNumber(String chapterUrl) {
    try {
      // Try to extract chapter number from URL patterns
      // Common patterns: chapter-123, chapter123, chap-123, etc.
      final regex = RegExp(r'chapter[_-]?(\d+)', caseSensitive: false);
      final match = regex.firstMatch(chapterUrl);
      if (match != null && match.groupCount >= 1) {
        return int.parse(match.group(1)!);
      }

      // Try to find any number in the URL
      final numberRegex = RegExp(r'(\d+)');
      final numberMatch = numberRegex.firstMatch(chapterUrl);
      if (numberMatch != null) {
        return int.parse(numberMatch.group(1)!);
      }

      // If no pattern found, return 0 as fallback
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get high-quality image URL (MangaDex search result, fallback to original)
  Future<String> _getHighQualityImageUrl(Comic comic) async {
    // Debug: Log which comic we're actually searching for
    print('🔍 DetailScreen: Starting MangaDex search for comic:');
    print('   Title: "${comic.title}"');
    print('   Detail URL: ${comic.detailUrl}');
    print('   Image URL: ${comic.imageUrl}');

    // Try to find manga on MangaDex first using the new service
    // Use the new method that can take advantage of alternative names
    print(
        '🔍 DetailScreen: Comic has ${comic.alternativeNames.length} alternative names');
    if (comic.alternativeNames.isNotEmpty) {
      for (int i = 0; i < comic.alternativeNames.length; i++) {
        print(
            '🔍 DetailScreen: Alternative name $i: "${comic.alternativeNames[i]}"');
      }
    }

    final mangaDexUrl =
        await MangaDexService.getMangaDexCoverUrlFromComic(comic);

    // If we found a MangaDex cover, use it
    if (mangaDexUrl != null) {
      print('🔍 DetailScreen: ✅ Found MangaDex cover: $mangaDexUrl');
      return mangaDexUrl;
    }

    // Otherwise, return the original URL
    print(
        '🔍 DetailScreen: ❌ No MangaDex cover found or validation failed, using original: ${comic.imageUrl}');
    return comic.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          RefreshIndicator(
        onRefresh: () async {
          // Force refresh both comic details and chapters
          setState(() {
            _comicFuture =
                NetTruyenService().forceRefreshComicDetails(widget.comic);
                _chaptersFuture = _loadInitialChapters();
                _imageFuture = _loadImage();
                _downloadFuture = Future.value(null); // reset HQ future
                // Reset "See More" state
                _allChapters = [];
                _currentOffset = 0;
                _hasMoreChapters = true;
                _isLoadingMore = false;
          });
        },
            child: CustomScrollView(
              slivers: [
                // Content
                SliverToBoxAdapter(
          child: Column(
            children: [
                      // Comic image and details
                      FutureBuilder<Comic>(
                  future: _comicFuture,
                  builder: (context, snapshot) {
                          // Show full-screen shimmer until comic data is loaded
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const FullScreenShimmer();
                          }

                    final comic = snapshot.data ?? widget.comic;
                          // Debug: Log which comic data we're using
                          print('🔍 DetailScreen: Using comic data:');
                          print('   Title: "${comic.title}"');
                          print('   Detail URL: ${comic.detailUrl}');
                          print('   Image URL: ${comic.imageUrl}');
                          print(
                              '   Source: ${snapshot.data != null ? "_comicFuture" : "widget.comic"}');

                    return Column(
                      children: [
                              // Comic image
                              AspectRatio(
                                aspectRatio:
                                    2 / 3, // Standard manga/comic cover ratio
                                child: FutureBuilder<_ImageResult>(
                                  future: _imageFuture,
                                  builder: (context, imageSnapshot) {
                                    if (imageSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const MangaDexSearchShimmer();
                                    }

                                    if (imageSnapshot.hasError ||
                                        !imageSnapshot.hasData) {
                                      // Fallback to original image on error
                                      return CachedNetworkImage(
                                        imageUrl: comic.imageUrl,
                                        fit: BoxFit.cover,
                                        cacheManager: _thumbCache,
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        placeholderFadeInDuration:
                                            Duration.zero,
                                        httpHeaders: {
                                          'User-Agent':
                                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                        },
                                        placeholder: (context, url) =>
                                            const MangaDexShimmerLoading(
                                          message: 'Đang tải...',
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                            child: Icon(Icons.error, size: 50),
                                          ),
                                        ),
                                      );
                                    }

                                    final imageResult = imageSnapshot.data!;

                                    if (imageResult.isCached) {
                                      // Display cached MangaDex image
                                      return Stack(
                                        children: [
                                          Image.memory(
                                            imageResult.cachedImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                          // Show MangaDex indicator
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green
                                                    .withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'HD',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else if (imageResult.isHq) {
                                      // Download and display high-quality image
                                      _downloadFuture ??=
                                          _downloadAndCacheMangaDexImage(
                                              imageResult.imageUrl);
                                      return FutureBuilder<Uint8List?>(
                                        future: _downloadFuture,
                                        builder: (context, downloadSnapshot) {
                                          if (downloadSnapshot
                                                  .connectionState ==
                                              ConnectionState.waiting) {
                                            return const MangaDexDownloadShimmer();
                                          }

                                          if (downloadSnapshot.hasError ||
                                              downloadSnapshot.data == null) {
                                            // If download fails, fallback to original
                                            print(
                                                '🔍 DetailScreen: MangaDex download failed, using original');
                                    return CachedNetworkImage(
                                      imageUrl: comic.imageUrl,
                                      fit: BoxFit.cover,
                                              cacheManager: _thumbCache,
                                              fadeInDuration: Duration.zero,
                                              fadeOutDuration: Duration.zero,
                                              placeholderFadeInDuration:
                                                  Duration.zero,
                                      httpHeaders: {
                                                'User-Agent':
                                                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                              },
                                              placeholder: (context, url) =>
                                                  const MangaDexShimmerLoading(
                                                message: 'Đang tải...',
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                                  child: Icon(Icons.error,
                                                      size: 50),
                                                ),
                                              ),
                                            );
                                          }

                                          // Display the downloaded MangaDex image
                                          return Stack(
                                      children: [
                                              Image.memory(
                                                downloadSnapshot.data!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                              // Show MangaDex indicator
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withValues(alpha: 0.9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: const Text(
                                                    'HD',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                    ),
                            ),
                          ],
                                          );
                                        },
                                      );
                                    } else {
                                      // Display original image
                                      return CachedNetworkImage(
                                        imageUrl: imageResult.imageUrl,
                                        fit: BoxFit.cover,
                                        cacheManager: _thumbCache,
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        placeholderFadeInDuration:
                                            Duration.zero,
                                        httpHeaders: {
                                          'User-Agent':
                                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                        },
                                        placeholder: (context, url) =>
                                            const MangaDexShimmerLoading(
                                          message: 'Đang tải...',
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(Icons.error, size: 50),
                                          ),
                                        ),
                                      );
                                    }
                  },
                ),
              ),

                              // Comic details
              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title
                                    Text(
                                      comic.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Info rows
                                    _buildInfoRow(
                                        'Tác giả',
                                        comic.author?.isNotEmpty == true
                                            ? comic.author!
                                            : 'Chưa có thông tin'),
                                    _buildInfoRow(
                                        'Trạng thái',
                                        comic.status?.isNotEmpty == true
                                            ? comic.status!
                                            : 'Chưa có thông tin'),
                                    _buildGenresRow('Thể loại', comic.genres),

                                    const SizedBox(height: 16),

                                    // Action buttons
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                child: FutureBuilder<List<String>>(
                  future: _chaptersFuture,
                  builder: (context, snapshot) {
                    final chapters = snapshot.data ?? [];
                                          final isLoading =
                                              snapshot.connectionState !=
                                                  ConnectionState.done;

                    return Column(
                      children: [
                                              // Reading progress section (only visible when there's progress or when chapters are loaded)
                                              if (_readingProgress != null || chapters.isNotEmpty) ...[
                                                const SizedBox(height: 24),
                                                Container(
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color: ThemeConstants.netflixDarkGray.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: ThemeConstants.netflixRed.withValues(alpha: 0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.bookmark,
                                                            color: ThemeConstants.netflixRed,
                                                            size: 20,
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            'Tiến độ đọc',
                                                            style: ThemeConstants.inconsolataSubheading.copyWith(
                                                              fontWeight: FontWeight.w600,
                                                              color: ThemeConstants.netflixRed,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  'Chương cuối đã đọc:',
                                                                  style: TextStyle(
                                                                    color: Colors.grey[600],
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                Text(
                                                                  (_readingProgress?['last_chapter_number'] ?? 0) > 0 
                                                                    ? 'Chapter ${_readingProgress?['last_chapter_number'] ?? 0}'
                                                                    : 'Chưa đọc',
                                                                   style: ThemeConstants.inconsolataBody.copyWith(
                                                                     fontWeight: FontWeight.w600,
                                                                   ),
                                                                 ),
                                                               ],
                                                             ),
                                                           ),
                                                           Column(
                                                             crossAxisAlignment: CrossAxisAlignment.end,
                                                             children: [
                                                               Text(
                                                                 'Hoàn thành:',
                                                                 style: TextStyle(
                                                                   color: Colors.grey[600],
                                                                   fontSize: 12,
                                                                 ),
                                                               ),
                                                               const SizedBox(height: 4),
                                                               Text(
                                                                 '${(_readingProgress?['completion_percentage'] ?? 0.0).toStringAsFixed(1)}%',
                                                                 style: ThemeConstants.inconsolataBody.copyWith(
                                                                   fontWeight: FontWeight.w600,
                                                                   color: ThemeConstants.netflixRed,
                                                                 ),
                                                               ),
                                                               const SizedBox(height: 2),
                                                               Text(
                                                                 '${_readingProgress?['last_chapter_number'] ?? 0} / ${_getLastAvailableChapter()} chương',
                                                                 style: TextStyle(
                                                                   color: Colors.grey[500],
                                                                   fontSize: 11,
                                                                 ),
                                                               ),
                                                               if (_readingProgress?['current_page'] != null) ...[
                                                                 const SizedBox(height: 2),
                                                                 Text(
                                                                   'Trang ${_readingProgress?['current_page'] ?? 0} / ${_readingProgress?['total_pages'] ?? '?'}',
                                                                   style: TextStyle(
                                                                     color: Colors.grey[500],
                                                                     fontSize: 11,
                                                                   ),
                                                                 ),
                                                               ],
                                                             ],
                                                           ),
                                                         ],
                                                       ),
                                                       const SizedBox(height: 12),
                                                       // Rainbow progress bar
                                                       Container(
                                                         height: 8,
                                                         decoration: BoxDecoration(
                                                           borderRadius: BorderRadius.circular(4),
                                                           border: Border.all(
                                                             color: Colors.grey[300]!,
                                                             width: 1,
                                                           ),
                                                         ),
                                                         child: ClipRRect(
                                                           borderRadius: BorderRadius.circular(4),
                                                           child: LinearProgressIndicator(
                                                             value: (_readingProgress?['completion_percentage'] ?? 0.0) / 100.0,
                                                             backgroundColor: Colors.grey[100],
                                                             valueColor: AlwaysStoppedAnimation<Color>(
                                                               _getRainbowColor(_readingProgress?['completion_percentage'] ?? 0.0),
                                                             ),
                                                             minHeight: 8,
                                                           ),
                                                         ),
                                                       ),
                                                       const SizedBox(height: 8),
                                                       Text(
                                                         _readingProgress?['last_read_at'] != null
                                                           ? 'Lần đọc cuối: ${_formatLastReadTime(_readingProgress?['last_read_at'] ?? 0)}'
                                                           : 'Chưa có tiến độ đọc',
                                                         style: TextStyle(
                                                           color: Colors.grey[500],
                                                           fontSize: 11,
                                                           fontStyle: FontStyle.italic,
                                                         ),
                                                       ),
                                                       const SizedBox(height: 12),
                                                       Row(
                                                         children: [
                            Expanded(
                                                             child: _buildActionButton(
                                                               onPressed: chapters.isEmpty || isLoading
                                    ? null
                                                                 : (_readingProgress?['last_chapter_url'] != null 
                                                                     ? () => _openReader(_readingProgress?['last_chapter_url'] ?? '')
                                                                     : () => _openReader(chapters[0])), // Đọc từ đầu if no progress
                                                               text: _readingProgress?['last_chapter_url'] != null 
                                                                 ? 'Tiếp tục đọc' 
                                                                 : 'Đọc từ đầu',
                                                               icon: _readingProgress?['last_chapter_url'] != null 
                                                                 ? Icons.play_arrow 
                                                                 : Icons.play_arrow,
                                                               backgroundColor: chapters.isEmpty || isLoading
                                                                 ? Colors.grey[400]!
                                                                 : ThemeConstants.netflixRed,
                                                               isFullWidth: true,
                                                             ),
                                                           ),
                                                           const SizedBox(width: 12),
                                                           _buildActionButton(
                                                             onPressed: _clearReadingProgress,
                                                             text: 'Xóa tiến độ',
                                                             icon: Icons.clear,
                                                             backgroundColor: Colors.grey[600]!,
                                                             isFullWidth: false,
                            ),
                          ],
                        ),
                                                     ],
                                                   ),
                                                 ),
                                               ],
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Chapter list
              Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                child: FutureBuilder<List<String>>(
                  future: _chaptersFuture,
                  builder: (ctx, snap) {
                                          if (snap.connectionState !=
                                              ConnectionState.done) {
                                            return const Center(
                                                child:
                                                    CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                                              child: Text(
                                                  'Error loading chapters:\n${snap.error}'),
                                            );
                                          }

                                          final initialChapters =
                                              snap.data ?? [];
                                          if (initialChapters.isEmpty) {
                                            return const Center(
                                                child:
                                                    Text('No chapters found.'));
                                          }

                                          // Use local state for chapters (includes loaded + additional)
                                          final allChapters =
                                              _allChapters.isNotEmpty
                                                  ? _allChapters
                                                  : initialChapters;

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Chapter header
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Danh sách chương (${allChapters.length} chương)',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                      // Show source indicator
                                                      if (_allChapters
                                                              .isNotEmpty &&
                                                          _allChapters !=
                                                              initialChapters)
                                                        Text(
                                                          'Đang hiển thị từ API',
                                                          style: TextStyle(
                                                            color:
                                                                ThemeConstants
                                                                    .netflixRed,
                                                            fontSize: 12,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        )
                                                      else if (initialChapters
                                                          .isNotEmpty)
                                                        Text(
                                                          'Đang hiển thị từ trang web',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[600],
                                                            fontSize: 12,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),

                                              // Chapter list
                                              _isLoadingMore
                                                  ? _buildShimmerChapterList(
                                                      allChapters.length)
                                                  : ListView.builder(
                      shrinkWrap: true,
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      itemCount:
                                                          allChapters.length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        final chapterUrl =
                                                            allChapters[index];
                                                        final actualChapterNumber =
                                                            _extractChapterNumber(
                                                                chapterUrl);

                                                        // If we can't extract a chapter number, fall back to index-based numbering
                                                        final displayChapterNumber =
                                                            actualChapterNumber >
                                                                    0
                                                                ? actualChapterNumber
                                                                : (allChapters
                                                                        .length -
                                                                    index);

                        return ListTile(
                                                          title: Text(
                                                              'Chapter $displayChapterNumber'),
                                                          subtitle: Text(
                                                            chapterUrl,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          trailing: const Icon(
                                                              Icons
                                                                  .chevron_right),
                                                          onTap: () =>
                                                              _openReader(
                                                                  allChapters[
                                                                      index]),
                                                        );
                                                      },
                                                    ),

                                              // "See More" button
                                              if (_hasMoreChapters ||
                                                  _isLoadingMore ||
                                                  allChapters.length >= 10) ...[
                                                const SizedBox(height: 24),
                                                Center(
                                                  child: _buildActionButton(
                                                    onPressed: _isLoadingMore
                                                        ? null
                                                        : _loadMoreChapters,
                                                    text: _isLoadingMore
                                                        ? 'Đang tải...'
                                                        : 'Tải thêm chương từ API',
                                                    icon: _isLoadingMore
                                                        ? Icons.hourglass_empty
                                                        : Icons.cloud_download,
                                                    backgroundColor:
                                                        _isLoadingMore
                                                            ? ThemeConstants
                                                                .netflixDarkGray
                                                            : ThemeConstants
                                                                .netflixRed,
                                                    isFullWidth: true,
                                                  ),
                                                ),
                                              ],

                                              // Reading progress section
                                            ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Potato.json loading overlay
          if (_isLoadingMore)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Potato animation
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Lottie.asset(
                        'assets/animations/Potato.json',
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Loading text
                    Text(
                      'Đang tải chương mới...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresRow(String label, List<Genre> genres) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: genres.map((genre) {
                return GestureDetector(
                  onTap: () {
                    // Navigate to genre page to show comics of this genre
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenreComicsScreen(
                          genreName: genre.name,
                          genreUrl: genre.url,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 4),
                    child: Text(
                      genre.name,
                      style: TextStyle(
                        color: ThemeConstants.netflixRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            ThemeConstants.netflixRed.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    required Color backgroundColor,
    bool isPrimary = true,
    bool isFullWidth = false,
  }) {
    Widget button = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            offset: const Offset(4, 4),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 0, // Remove default elevation since we have custom shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    // Return the button directly - let the parent Row handle the Expanded logic
    return button;
  }

  Widget _buildShimmerChapterList(int itemCount) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chapter title shimmer
                      Container(
                        height: 20,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Chapter URL shimmer
                      Container(
                        height: 15,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Chevron icon shimmer
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
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
