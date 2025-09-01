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
    print('🔍 ReaderScreen: initState called with chapterUrl: ${widget.chapterUrl}');

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
    
    // Add listener to track scroll position changes
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients) {
        print('🔍 ReaderScreen: Scroll position changed - Offset: ${_scrollCtrl.offset.toStringAsFixed(1)}, MaxExtent: ${_scrollCtrl.position.maxScrollExtent.toStringAsFixed(1)}');
        
        // Check PageStorage state
        final context = this.context;
        if (context.mounted) {
          final pageStorage = PageStorage.of(context);
          if (pageStorage != null) {
            print('🔍 ReaderScreen: PageStorage found in context');
          } else {
            print('🔍 ReaderScreen: PageStorage not found in context');
          }
        }
      }
    });
    
    // Try to restore scroll position after a delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestoreScrollPosition();
    });
  }

  // Try to restore scroll position if PageStorage didn't work automatically
  void _tryRestoreScrollPosition() {
    if (_scrollCtrl.hasClients && _chapterImages.isNotEmpty) {
      // Wait a bit for content to be fully rendered
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollCtrl.hasClients) {
          final currentOffset = _scrollCtrl.offset;
          print('🔍 ReaderScreen: Checking scroll position - Current: ${currentOffset.toStringAsFixed(1)}');
          
          // Check PageStorage state manually
          final context = this.context;
          if (context.mounted) {
            final pageStorage = PageStorage.of(context);
            if (pageStorage != null) {
              print('🔍 ReaderScreen: PageStorage found - Bucket: $_scrollStorageBucket');
              
              // Try to manually check stored data
              final storedData = pageStorage.readState(context, identifier: 'reader_scroll_${widget.chapterUrl.hashCode}');
              if (storedData != null) {
                print('🔍 ReaderScreen: Found stored data: $storedData');
              } else {
                print('🔍 ReaderScreen: No stored data found in PageStorage');
              }
            } else {
              print('🔍 ReaderScreen: PageStorage not found in context');
            }
          }
          
          // If we're at the top and should have a saved position, try to restore
          if (currentOffset == 0.0) {
            print('🔍 ReaderScreen: At top position - PageStorage may not have worked');
          }
        }
      });
    }
  }

  // Manually save scroll position to PageStorage for testing
  void _saveScrollPositionToPageStorage() {
    if (_scrollCtrl.hasClients && _chapterImages.isNotEmpty) {
      final currentOffset = _scrollCtrl.offset;
      final context = this.context;
      
      if (context.mounted) {
        final pageStorage = PageStorage.of(context);
        if (pageStorage != null) {
          final identifier = 'reader_scroll_${widget.chapterUrl.hashCode}';
          pageStorage.writeState(context, currentOffset, identifier: identifier);
          print('🔍 ReaderScreen: Manually saved scroll position to PageStorage: ${currentOffset.toStringAsFixed(1)}');
        } else {
          print('🔍 ReaderScreen: Cannot save - PageStorage not found');
        }
      }
    }
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
        
        print('🔍 ReaderScreen: Extracted comic detail URL: $_comicDetailUrl');
      } else {
        print('🔍 ReaderScreen: Could not extract comic detail URL from: ${widget.chapterUrl}');
      }
    } catch (e) {
      print('🔍 ReaderScreen: Error extracting comic detail URL: $e');
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Save last read chapter info (simplified)
  void _saveLastReadChapter() async {
    // Flutter's built-in scroll restoration handles this automatically!
    print('🔍 ReaderScreen: Flutter handles scroll restoration automatically');
  }

  // Save visibility tracking data for precise restoration
  void _saveVisibilityTrackingData() {
    // Flutter's built-in scroll restoration handles this automatically!
    print('🔍 ReaderScreen: Flutter handles scroll restoration automatically');
  }

  // Save progress to SharedPreferences
  void _saveProgressToPreferences(double progress) async {
    // Flutter's built-in scroll restoration handles this automatically!
    print('🔍 ReaderScreen: Flutter handles scroll restoration automatically');
  }

  Future<void> _loadChapter() async {
    print('🔍 ReaderScreen: _loadChapter called');
    print('🔍 ReaderScreen: Chapter URL: ${widget.chapterUrl}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if we have cached images for this chapter
      if (_imageCache.containsKey(widget.chapterUrl)) {
        print('🔍 ReaderScreen: Found cached images for chapter');
        setState(() {
          _chapterImages = _imageCache[widget.chapterUrl]!;
          _isLoading = false;
        });
        
        // Wait for content to be ready, then show reading screen
        return;
      }

      // Load chapter from network (first time reading)
      print('🔍 ReaderScreen: Loading chapter from network...');
      await _loadChapterFromNetwork();
      
    } catch (e) {
      print('🔍 ReaderScreen: Error loading chapter: $e');
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
    print('🔍 ReaderScreen: Loading fresh chapter from network: ${widget.chapterUrl}');
    
    // Clear existing images
    setState(() {
      _chapterImages.clear();
    });

    // Load chapter with progressive loading and caching
    final List<String> imageUrls = [];
    await NetTruyenService().fetchChapterPagesWithCallback(
      widget.chapterUrl,
      onImageFound: (imageUrl) {
        print('🔍 ReaderScreen: Image found: $imageUrl');
        imageUrls.add(imageUrl);
      },
    );

    print('🔍 ReaderScreen: Network chapter loading completed. Total images: ${imageUrls.length}');
    
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
      
      print('🔍 ReaderScreen: Chapter loaded and cached successfully');
      
      // Wait for content to be ready, then show reading screen
      return;
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No images found for this chapter';
      });
    }
  }

  // Simple display pages getter
  List<PageItem> get _displayPages => _chapterImages;

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


  // Build page navigation floating action button
  Widget _buildPageNavigationFAB() {
    if (_chapterImages.length <= 1) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: () {
        // Calculate current page based on scroll position
        final currentPage = _scrollCtrl.hasClients && _chapterImages.length > 1
            ? ((_scrollCtrl.offset / _scrollCtrl.position.maxScrollExtent) * _chapterImages.length).round().clamp(1, _chapterImages.length)
            : 1;
            
        final newPage = currentPage + 1;
        if (newPage <= _chapterImages.length) {
          _scrollCtrl.animateTo(
            _scrollCtrl.offset + MediaQuery.of(context).size.height * 0.8, // Scroll to the next page
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      label: const Text('Next Page'),
      icon: const Icon(Icons.arrow_forward_ios),
      backgroundColor: Colors.black87,
      foregroundColor: Colors.white,
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
          print('🔍 ReaderScreen: PopScope triggered - user is leaving');
          // Manually save scroll position to PageStorage for testing
          _saveScrollPositionToPageStorage();
          print('🔍 ReaderScreen: Flutter handles scroll restoration automatically');
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
    print('🔍 ReaderScreen: build called');
    print('🔍 ReaderScreen: _isLoading: $_isLoading');
    // print('🔍 ReaderScreen: _isContentReady: $_isContentReady'); // Removed as per edit hint
    print('🔍 ReaderScreen: _displayPages.length: ${_displayPages.length}');

    if (_isLoading) {
      return _buildSimpleLoading();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return _buildMainReadingScreen();
  }
}
