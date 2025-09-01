// lib/screens/reader_screen.dart

import 'package:flutter/material.dart';
import 'package:nettruyen_reader/services/nettruyen_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Custom SliverPersistentHeaderDelegate for collapsible page indicator
class _PageIndicatorDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _PageIndicatorDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate opacity based on scroll position
    // When shrinkOffset is 0, we're at the top (show indicator)
    // When shrinkOffset is maxExtent, we're scrolled down (hide indicator)
    final progress = shrinkOffset / maxExtent;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    // Add a small threshold to make the transition smoother
    final threshold = 0.2;
    final smoothOpacity = opacity < threshold ? 0.0 : opacity;

    // CHANGED: Remove AnimatedContainer/AnimatedOpacity to avoid jank on every scroll tick.
    return Opacity(
      opacity: smoothOpacity,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    // Keep true so updates to `child` (page text/progress) reflect.
    return true;
  }
}

class ReaderScreen extends StatefulWidget {
  final String chapterUrl;

  const ReaderScreen({
    Key? key,
    required this.chapterUrl,
  }) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with AutomaticKeepAliveClientMixin {
  // Use ScrollController with restoration
  late final ScrollController _scrollCtrl;
  
  List<PageItem> _chapterImages = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Simple image cache using Map
  static final Map<String, List<PageItem>> _imageCache = {};
  
  // Page tracking variables
  String? _comicDetailUrl;
  
  // Persistent PageStorage bucket for scroll position preservation
  static final PageStorageBucket _scrollStorageBucket = PageStorageBucket();

  @override
  bool get wantKeepAlive => true; // Keep state alive when navigating

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method gets the current domain for use in headers.
  /// It ensures that chapter pages are loaded with the correct Referer header.
  Future<String> _getCurrentDomainForHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('custom_domain') ?? 'https://nettruyenvia.com'; // Default to primary domain
  }

  @override
  void initState() {
    super.initState();

    // Extract comic detail URL from chapter URL
    _extractComicDetailUrl();

    // Load chapter data
    _loadChapter();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize ScrollController with restoration here (after dependencies are available)
    _scrollCtrl = ScrollController(
      keepScrollOffset: true, // Enable scroll offset preservation
    );
  }

  // Extract comic detail URL from chapter URL
  void _extractComicDetailUrl() {
    try {
      // Parse the chapter URL to get the comic detail URL
      final uri = Uri.parse(widget.chapterUrl);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 2) {
        // Remove the last segment (chapter number) and reconstruct the comic detail URL
        final comicPathSegments = pathSegments.take(pathSegments.length - 1);
        final comicPath = '/${comicPathSegments.join('/')}';
        _comicDetailUrl = '${uri.scheme}://${uri.host}$comicPath';
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if we have cached images for this chapter
      if (_imageCache.containsKey(widget.chapterUrl)) {
        setState(() {
          _chapterImages = _imageCache[widget.chapterUrl]!;
          _isLoading = false;
        });
        return;
      }

      // Load chapter from network (first time reading)
      await _loadChapterFromNetwork();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load chapter: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Load chapter from network (fresh data)
  Future<void> _loadChapterFromNetwork() async {
    // Clear existing images
    setState(() {
      _chapterImages.clear();
    });

    // Load chapter with progressive loading and caching
    final List<String> imageUrls = [];
    await NetTruyenService().fetchChapterPagesWithCallback(
      widget.chapterUrl,
      onImageFound: (imageUrl) {
        imageUrls.add(imageUrl);
      },
    );

    // Create PageItem objects and cache them
    if (imageUrls.isNotEmpty) {
      final List<PageItem> pageItems = [];
      
      for (int i = 0; i < imageUrls.length; i++) {
        pageItems.add(PageItem(
          imageUrl: imageUrls[i],
          chapterIndex: i,
        ));
      }
      
      // Cache the images
      _imageCache[widget.chapterUrl] = pageItems;
      
      // Update state
      setState(() {
        _chapterImages = pageItems;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No images found for this chapter';
      });
    }
  }

  // Helper to build a single page widget
  Widget _buildPageWidget(int index) {
    final page = _chapterImages[index];
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: CachedNetworkImage(
        imageUrl: page.imageUrl,
        httpHeaders: {'Referer': _getRefererHeader()}, // Use dynamic referer
        fit: BoxFit.contain,
        width: double.infinity,
        placeholder: (context, url) => Container(
          height: 400,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[600]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.red[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red[200], size: 48),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.red[200], fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Get the referer header for image loading
  String _getRefererHeader() {
    try {
      final uri = Uri.parse(widget.chapterUrl);
      return '${uri.scheme}://${uri.host}';
    } catch (e) {
      return 'https://nettruyenvia.com'; // Fallback
    }
  }

  // Build page indicator widget


  // Build chapter navigation floating action buttons
  Widget _buildPageNavigationFAB() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Previous chapter button
        FloatingActionButton.extended(
          heroTag: 'prev_chapter_btn',
          onPressed: () async {
            // Navigate to previous chapter
            try {
              final prevChapterUrl = await NetTruyenService().getPreviousChapterUrl(widget.chapterUrl);
              if (prevChapterUrl != null) {
                // Navigate to the previous chapter
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReaderScreen(chapterUrl: prevChapterUrl),
                    ),
                  );
                }
              } else {
                // Show message that there's no previous chapter
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đây là chương đầu tiên'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            } catch (e) {
              // Show error message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi khi tải chương trước: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          },
          label: const Text('Chương trước'),
          icon: const Icon(Icons.arrow_back_ios),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
        ),
        const SizedBox(width: 16),
        // Next chapter button
        FloatingActionButton.extended(
          heroTag: 'next_chapter_btn',
          onPressed: () async {
            // Navigate to next chapter instead of next page
            try {
              final nextChapterUrl = await NetTruyenService().getNextChapterUrl(widget.chapterUrl);
              if (nextChapterUrl != null) {
                // Navigate to the next chapter
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReaderScreen(chapterUrl: nextChapterUrl),
                    ),
                  );
                }
              } else {
                // Show message that there's no next chapter
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đây là chương cuối cùng'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            } catch (e) {
              // Show error message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi khi tải chương tiếp theo: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          },
          label: const Text('Chương tiếp'),
          icon: const Icon(Icons.arrow_forward_ios),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildSimpleLoading() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading chapter...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text('Error', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load chapter',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadChapter,
              child: const Text('Retry'),
            ),
          ],
        ),
        ),
      );
    }

  Widget _buildMainReadingScreen() {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          // Flutter's built-in scroll restoration handles everything automatically!
          // No debug output needed
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,

        body: PageStorage(
          bucket: _scrollStorageBucket,
          child: CustomScrollView(
            key: PageStorageKey<String>('reader_scroll_${widget.chapterUrl.hashCode}'), // Unique storage key for this chapter
            restorationId: 'reader_restore_${widget.chapterUrl.hashCode}', // Restoration ID for this chapter
            physics: const BouncingScrollPhysics(),
            controller: _scrollCtrl,
            slivers: [
              // Chapter pages with simple SliverList
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildPageWidget(index);
                  },
                  childCount: _chapterImages.length,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildPageNavigationFAB(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_isLoading) {
      return _buildSimpleLoading();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return _buildMainReadingScreen();
  }
}
