// lib/screens/detail_screen.dart



import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';


import '../models/comic.dart';

import '../services/nettruyen_service.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';
import '../services/mangadex_service.dart';

import '../widgets/mangadex_shimmer_loading.dart';
import '../widgets/full_screen_shimmer.dart';
import 'reader_screen.dart';
import '../services/comic_search_delegate.dart';
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
  late CacheManager _thumbCache;
  String? _lastUsedDomain;
  
  // 👇 Cache the futures so shimmer won't flash on rebuilds
  late Future<_ImageResult> _imageFuture;
  Future<Uint8List?>? _downloadFuture;
  
  // New state variables for "See More" functionality
  List<String> _allChapters = [];
  bool _isLoadingMore = false;
  bool _hasMoreChapters = true;
  int _currentOffset = 0;
  static const int _chaptersPerBatch = 50;

  @override
  void initState() {
    super.initState();
    _comicFuture = NetTruyenService().updateComicWithDetails(widget.comic);
    _thumbCache = CacheManager(Config(AppConstants.THUMB_CACHE_KEY));
    
    // Load initial chapters
    _chaptersFuture = _loadInitialChapters();
    
    // Memoized future — won't restart on rebuild
    _imageFuture = _loadImage();
  }

  /// Load initial chapters and set up state for "See More"
  Future<List<String>> _loadInitialChapters() async {
    try {
      final chapters = await NetTruyenService().fetchChapters(widget.comic.detailUrl);
      _allChapters = chapters;
      _currentOffset = chapters.length;
      
      // More lenient logic: show button if we have a reasonable number of chapters
      // This assumes most comics have more than what's visible in HTML
      _hasMoreChapters = chapters.length >= 10; // Show button for comics with 10+ chapters
      
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
        
        print('🔍 DetailScreen: Replaced list with ${moreChapters.length} chapters from API');
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
      print('🔍 DetailScreen: _loadImage using fresh comic data with ${comic.alternativeNames.length} alternative names');
      
      // First, check if we have a cached MangaDex thumbnail
      if (await MangaDexService.hasCachedThumbnail(comic.detailUrl)) {
        final cache = await MangaDexService.getCachedThumbnail(comic.detailUrl);
        if (cache != null) {
          print('🔍 DetailScreen: ✅ Using cached MangaDex thumbnail');
          return _ImageResult(isCached: true, isHq: false, imageUrl: '', cachedImage: cache);
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
      return _ImageResult(isCached: false, isHq: false, imageUrl: comic.imageUrl);
    } catch (e) {
      print('🔍 DetailScreen: ❌ Error in _loadImage: $e');
      return _ImageResult(isCached: false, isHq: false, imageUrl: widget.comic.imageUrl);
    }
  }
  
  /// Download and cache MangaDex image from URL
  Future<Uint8List?> _downloadAndCacheMangaDexImage(String mangadexUrl) async {
    try {
      print('🔍 DetailScreen: 📥 Downloading and caching MangaDex image');
      final downloadedImage = await MangaDexService.downloadMangaDexImage(
        mangadexUrl, 
        comicUrl: widget.comic.detailUrl
      );
      
      if (downloadedImage != null) {
        print('🔍 DetailScreen: ✅ Successfully downloaded and cached MangaDex image');
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

  void _openReader(List<String> chapters, int chapterIndex) {
    if (chapterIndex >= 0 && chapterIndex < chapters.length) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(
            chapters: chapters,
            initialIndex: chapterIndex,
          ),
        ),
      );
    }
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
      print('🔍 DetailScreen: Comic has ${comic.alternativeNames.length} alternative names');
      if (comic.alternativeNames.isNotEmpty) {
        for (int i = 0; i < comic.alternativeNames.length; i++) {
          print('🔍 DetailScreen: Alternative name $i: "${comic.alternativeNames[i]}"');
        }
      }
      
      final mangaDexUrl = await MangaDexService.getMangaDexCoverUrlFromComic(comic);
    
    // If we found a MangaDex cover, use it
    if (mangaDexUrl != null) {
      print('🔍 DetailScreen: ✅ Found MangaDex cover: $mangaDexUrl');
      return mangaDexUrl;
    }
    
    // Otherwise, return the original URL
    print('🔍 DetailScreen: ❌ No MangaDex cover found or validation failed, using original: ${comic.imageUrl}');
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
                _downloadFuture = null; // reset HQ future
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const FullScreenShimmer();
                    }

                    final comic = snapshot.data ?? widget.comic;
                          // Debug: Log which comic data we're using
                          print('🔍 DetailScreen: Using comic data:');
                          print('   Title: "${comic.title}"');
                          print('   Detail URL: ${comic.detailUrl}');
                          print('   Image URL: ${comic.imageUrl}');
                          print('   Source: ${snapshot.data != null ? "_comicFuture" : "widget.comic"}');

                    return Column(
                      children: [
                              // Comic image
                            AspectRatio(
                              aspectRatio: 2/3, // Standard manga/comic cover ratio
                            child: FutureBuilder<_ImageResult>(
                              future: _imageFuture,
                              builder: (context, imageSnapshot) {
                                    if (imageSnapshot.connectionState == ConnectionState.waiting) {
                                      return const MangaDexSearchShimmer();
                                    }

                                    if (imageSnapshot.hasError || !imageSnapshot.hasData) {
                                  // Fallback to original image on error
                                  return CachedNetworkImage(
                                    imageUrl: comic.imageUrl,
                                    fit: BoxFit.cover,
                                    cacheManager: _thumbCache,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholderFadeInDuration: Duration.zero,
                                    httpHeaders: {
                                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                    },
                                    placeholder: (context, url) => const MangaDexShimmerLoading(
                                      message: 'Đang tải...',
                                    ),
                                    errorWidget: (context, url, error) => Container(
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
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(4),
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
                                  _downloadFuture ??= _downloadAndCacheMangaDexImage(imageResult.imageUrl);
                                  return FutureBuilder<Uint8List?>(
                                    future: _downloadFuture,
                                    builder: (context, downloadSnapshot) {
                                      if (downloadSnapshot.connectionState == ConnectionState.waiting) {
                                        return const MangaDexDownloadShimmer();
                                      }

                                      if (downloadSnapshot.hasError || downloadSnapshot.data == null) {
                                        // If download fails, fallback to original
                                        print('🔍 DetailScreen: MangaDex download failed, using original');
                                        return CachedNetworkImage(
                                          imageUrl: comic.imageUrl,
                                          fit: BoxFit.cover,
                                          cacheManager: _thumbCache,
                                          fadeInDuration: Duration.zero,
                                          fadeOutDuration: Duration.zero,
                                          placeholderFadeInDuration: Duration.zero,
                                          httpHeaders: {
                                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                          },
                                          placeholder: (context, url) => const MangaDexShimmerLoading(
                                            message: 'Đang tải...',
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: Icon(Icons.error, size: 50),
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
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.9),
                                                borderRadius: BorderRadius.circular(4),
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
                                    placeholderFadeInDuration: Duration.zero,
                                    httpHeaders: {
                                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                    },
                                    placeholder: (context, url) => const MangaDexShimmerLoading(
                                      message: 'Đang tải...',
                                    ),
                                    errorWidget: (context, url, error) => Container(
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
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Info rows
                                    _buildInfoRow('Tác giả', comic.author?.isNotEmpty == true ? comic.author! : 'Chưa có thông tin'),
                                    _buildInfoRow('Trạng thái', comic.status?.isNotEmpty == true ? comic.status! : 'Chưa có thông tin'),
                                    _buildGenresRow('Thể loại', comic.genres),

                                    const SizedBox(height: 16),

              // Action buttons
                                    Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<List<String>>(
                  future: _chaptersFuture,
                  builder: (context, snapshot) {
                    final chapters = snapshot.data ?? [];
                                          final isLoading = snapshot.connectionState != ConnectionState.done;
                                          
                    return Column(
                      children: [
                                              // Top row: Read from beginning and Read latest
                        Row(
                          children: [
                            Expanded(
                                                    child: _buildActionButton(
                                                      onPressed: chapters.isEmpty || isLoading
                                    ? null
                                    : () => _openReader(chapters, 0),
                                                      text: 'Đọc từ đầu',
                                                      icon: Icons.play_arrow,
                                                      backgroundColor: isLoading 
                                                          ? ThemeConstants.netflixRed.withValues(alpha: 0.6)
                                                          : ThemeConstants.netflixRed,
                                                      isPrimary: true,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12), // Reduced spacing
                            Expanded(
                                                    child: _buildActionButton(
                                                      onPressed: chapters.isEmpty || isLoading
                                    ? null
                                    : () => _openReader(
                                        chapters, chapters.length - 1),
                                                      text: 'Đọc mới', // Shortened text
                                                      icon: Icons.new_releases,
                                                      backgroundColor: isLoading 
                                                          ? Colors.orange.withValues(alpha: 0.6)
                                                          : Colors.orange,
                                                      isPrimary: true,
                              ),
                            ),
                          ],
                        ),
                                              const SizedBox(height: 16),
                                              // Bottom row: Find similar comics
                                              _buildActionButton(
                                                onPressed: isLoading ? null : () {
                              showSearch(
                                context: context,
                                delegate: ComicSearchDelegate(),
                                query: '',
                              );
                            },
                                                text: 'Tìm truyện tương tự',
                                                icon: Icons.search,
                                                backgroundColor: isLoading 
                                                    ? ThemeConstants.netflixDarkGray.withValues(alpha: 0.6)
                                                    : ThemeConstants.netflixDarkGray,
                                                isPrimary: false,
                                                isFullWidth: true,
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Chapter list
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<List<String>>(
                  future: _chaptersFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text('Error loading chapters:\n${snap.error}'),
                      );
                    }

                                          final initialChapters = snap.data ?? [];
                                          if (initialChapters.isEmpty) {
                      return const Center(child: Text('No chapters found.'));
                    }

                                          // Use local state for chapters (includes loaded + additional)
                                          final allChapters = _allChapters.isNotEmpty ? _allChapters : initialChapters;

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Chapter header
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Danh sách chương (${allChapters.length} chương)',
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      // Show source indicator
                                                      if (_allChapters.isNotEmpty && _allChapters != initialChapters)
                                                        Text(
                                                          'Đang hiển thị từ API',
                                                          style: TextStyle(
                                                            color: ThemeConstants.netflixRed,
                                                            fontSize: 12,
                                                            fontStyle: FontStyle.italic,
                                                          ),
                                                        )
                                                      else if (initialChapters.isNotEmpty)
                                                        Text(
                                                          'Đang hiển thị từ trang web',
                                                          style: TextStyle(
                                                            color: Colors.grey[600],
                                                            fontSize: 12,
                                                            fontStyle: FontStyle.italic,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),

                                              // Chapter list
                                              _isLoadingMore 
                                                  ? _buildShimmerChapterList(allChapters.length)
                                                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                                                      itemCount: allChapters.length,
                      itemBuilder: (context, index) {
                                                        final chapterUrl = allChapters[index];
                                                        final actualChapterNumber = _extractChapterNumber(chapterUrl);
                                                        
                                                        // If we can't extract a chapter number, fall back to index-based numbering
                                                        final displayChapterNumber = actualChapterNumber > 0 
                                                            ? actualChapterNumber 
                                                            : (allChapters.length - index);

                        return ListTile(
                                                          title: Text('Chapter $displayChapterNumber'),
                                                          subtitle: Text(
                                                            chapterUrl,
                                                            style: TextStyle(
                                                              color: Colors.grey[600],
                                                              fontSize: 12,
                                                            ),
                                                          ),
                          trailing: const Icon(Icons.chevron_right),
                                                          onTap: () => _openReader(allChapters, index),
                                                        );
                                                      },
                                                    ),

                                              // "See More" button
                                              if (_hasMoreChapters || _isLoadingMore || allChapters.length >= 10) ...[
                                                const SizedBox(height: 24),
                                                Center(
                                                  child: _buildActionButton(
                                                    onPressed: _isLoadingMore ? null : _loadMoreChapters,
                                                    text: _isLoadingMore ? 'Đang tải...' : 'Tải thêm chương từ API',
                                                    icon: _isLoadingMore ? Icons.hourglass_empty : Icons.cloud_download,
                                                    backgroundColor: _isLoadingMore 
                                                        ? ThemeConstants.netflixDarkGray 
                                                        : ThemeConstants.netflixRed,
                                                    isFullWidth: true,
                                                  ),
                                                ),
                                              ],
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
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
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
