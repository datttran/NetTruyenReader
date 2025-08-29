// lib/screens/reader_screen.dart

import 'package:flutter/material.dart';
import 'package:nettruyen_reader/constants/theme_constants.dart';
import 'dart:async';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../services/nettruyen_service.dart';
import '../services/database_helper.dart';
import '../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

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

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<PageItem> _chapterImages = [];
  bool _isLoading = true;
  bool _isContentReady = false; // New state for content readiness
  String? _errorMessage;

  // Sliver visibility tracking for precise restoration
  int _lastVisibleItemIndex = 0;
  double _lastVisibleItemLocalOffset = 0.0;

  // Page tracking variables
  String? _comicDetailUrl;

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method gets the current domain for use in headers.
  /// It ensures that chapter pages are loaded with the correct Referer header.
  Future<String> _getCurrentDomainForHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('custom_domain') ?? AppConstants.PRIMARY_DOMAIN;
  }

  @override
  void initState() {
    super.initState();
    print('🔍 ReaderScreen: initState called with chapterUrl: ${widget.chapterUrl}');

    // Debug database structure to help troubleshoot
    _debugDatabaseStructure();

    // Extract comic detail URL from chapter URL
    _extractComicDetailUrl();

    // Setup scroll listener for page tracking and progress saving
    _setupScrollListener();

    _loadChapter();
  }

  // Debug database structure to help troubleshoot
  Future<void> _debugDatabaseStructure() async {
    try {
      await _databaseHelper.debugDatabaseStructure();
    } catch (e) {
      print('🔍 ReaderScreen: Error debugging database structure: $e');
    }
  }

  // Extract comic detail URL from chapter URL
  void _extractComicDetailUrl() {
    print('🔍 ReaderScreen: _extractComicDetailUrl called with chapterUrl: ${widget.chapterUrl}');

    try {
      // Parse the chapter URL to get the comic detail URL
      // Example: https://nettruyenvia.com//truyen-tranh/one-piece/chuong-1144
      // We want: https://nettruyenvia.com/truyen-tranh/one-piece (normalized)

      final uri = Uri.parse(widget.chapterUrl);
      final pathSegments = uri.pathSegments;

      print('🔍 ReaderScreen: URI path segments: $pathSegments');

      if (pathSegments.length >= 2) {
        // Remove the last segment (chapter number) and reconstruct the comic detail URL
        final comicPathSegments = pathSegments.take(pathSegments.length - 1);
        final comicPath = '/${comicPathSegments.join('/')}';

        // Normalize the URL to match DetailScreen format (single slash)
        final normalizedPath = comicPath.replaceAll('//', '/');
        _comicDetailUrl = '${uri.scheme}://${uri.host}$normalizedPath';

        print('🔍 ReaderScreen: ✅ Comic detail URL extracted and normalized: $_comicDetailUrl');
      } else {
        print('🔍 ReaderScreen: ❌ Invalid chapter URL format - not enough path segments');
        _comicDetailUrl = null;
      }
    } catch (e) {
      print('🔍 ReaderScreen: ❌ Error extracting comic detail URL: $e');
      _comicDetailUrl = null;
    }
  }

  // Setup scroll listener for page tracking and progress saving
  void _setupScrollListener() {
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients && _chapterImages.isNotEmpty) {
        final offset = _scrollCtrl.offset;
        final totalHeight = _scrollCtrl.position.maxScrollExtent;

        print('🔍 ReaderScreen: Scroll Event - Offset: ${offset.toStringAsFixed(1)}, TotalHeight: ${totalHeight.toStringAsFixed(1)}');

        // Track visible items for precise restoration
        _updateVisibleItemTracking(offset);
      } else {
        print('🔍 ReaderScreen: Scroll listener - No clients or no images. HasClients: ${_scrollCtrl.hasClients}, ImagesCount: ${_chapterImages.length}');
      }
    });
    print('🔍 ReaderScreen: Scroll listener setup complete');
  }

  // Track which Sliver items are visible and their local positions
  void _updateVisibleItemTracking(double scrollOffset) {
    if (_chapterImages.isEmpty) return;

    // Get viewport dimensions for more accurate calculations
    // Store context and MediaQuery data before async operations to avoid BuildContext issues
    final context = this.context;
    if (!context.mounted) return;
    
    final viewportHeight = MediaQuery.of(context).size.height;
    
    // Calculate actual item heights dynamically instead of assuming 400px
    // This is more accurate for chapters with variable image heights
    final totalHeight = _scrollCtrl.position.maxScrollExtent;
    final actualItemHeight = totalHeight / _chapterImages.length;
    
    // Calculate which item is most visible in the viewport
    // Consider the center of the viewport as the "visible" point
    final viewportCenter = scrollOffset + (viewportHeight / 2);
    final estimatedIndex = (viewportCenter / actualItemHeight).floor();
    
    if (estimatedIndex >= 0 && estimatedIndex < _chapterImages.length) {
      _lastVisibleItemIndex = estimatedIndex;
      
      // Calculate local offset from the TOP of the current item
      // This is much simpler and more accurate than global calculations
      final itemStartOffset = estimatedIndex * actualItemHeight;
      _lastVisibleItemLocalOffset = viewportCenter - itemStartOffset;
      
      // Clamp local offset to item bounds (0 to actualItemHeight)
      _lastVisibleItemLocalOffset = _lastVisibleItemLocalOffset.clamp(0.0, actualItemHeight);
      
      print('🔍 ReaderScreen: 📍 Visible tracking - Item: $_lastVisibleItemIndex, Local offset from item top: ${_lastVisibleItemLocalOffset.toStringAsFixed(1)}');
      print('🔍 ReaderScreen: 📍 Actual item height: ${actualItemHeight.toStringAsFixed(1)}, Total height: ${totalHeight.toStringAsFixed(1)}');
      print('🔍 ReaderScreen: 📍 Item start in global scroll: ${itemStartOffset.toStringAsFixed(1)}, Viewport center: ${viewportCenter.toStringAsFixed(1)}');
    }
  }

  @override
  void dispose() {
    // Progress is already saved on exit via PopScope, so no need to save again here
    print('🔍 ReaderScreen: Disposing - progress already saved on exit');
    
    _scrollCtrl.dispose();
    super.dispose();
  }

  // SINGLE SAVE POINT: Save progress when user exits the reader screen
  void _saveProgressOnExit() {
    if (_comicDetailUrl != null && _chapterImages.isNotEmpty) {
      // Get the current scroll offset immediately
      double scrollOffset = 0.0;
      
      if (_scrollCtrl.hasClients) {
        scrollOffset = _scrollCtrl.offset;
        print('🔍 ReaderScreen: 🚪 Exit detected - saving progress immediately');
        print('🔍 ReaderScreen: Current offset: ${scrollOffset.toStringAsFixed(1)}, Total: ${_chapterImages.length}');
        print('🔍 ReaderScreen: Visible item: $_lastVisibleItemIndex, Local offset: ${_lastVisibleItemLocalOffset.toStringAsFixed(1)}');
        print('🔍 ReaderScreen: ScrollController state - HasClients: ${_scrollCtrl.hasClients}, Offset: ${_scrollCtrl.offset}, MaxScrollExtent: ${_scrollCtrl.position.maxScrollExtent}');
        
        // Save chapter-specific reading progress with visibility tracking
        _databaseHelper.saveChapterReadingProgress(
          chapterUrl: widget.chapterUrl, // Save for THIS specific chapter
          currentPage: _lastVisibleItemIndex + 1, // Convert to 1-based page number
          scrollOffset: scrollOffset,
          totalPages: _chapterImages.length,
        );
        
        // Also save the visibility tracking data for precise restoration
        _saveVisibilityTrackingData();
        
        print('🔍 ReaderScreen: ✅ Exit progress saved successfully for chapter: ${widget.chapterUrl}');
      } else {
        print('🔍 ReaderScreen: ❌ ScrollController has no clients during exit save');
      }
    } else {
      print('🔍 ReaderScreen: ❌ Cannot save exit progress - ComicDetailUrl: $_comicDetailUrl, ImagesCount: ${_chapterImages.length}');
    }
  }

  // Save visibility tracking data for precise restoration
  void _saveVisibilityTrackingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'visibility_${widget.chapterUrl}';
      final data = {
        'itemIndex': _lastVisibleItemIndex,
        'localOffset': _lastVisibleItemLocalOffset,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(key, data.toString());
      print('🔍 ReaderScreen: ✅ Visibility tracking data saved: $data');
    } catch (e) {
      print('🔍 ReaderScreen: ❌ Error saving visibility tracking data: $e');
    }
  }

  // Restore scroll position from saved progress
  Future<void> _restoreScrollPosition() async {
    print('🔍 ReaderScreen: _restoreScrollPosition called - Chapter URL: ${widget.chapterUrl}');
    
    try {
      // First try to restore using visibility tracking data (most precise)
      final visibilityData = await _loadVisibilityTrackingData();
      
      if (visibilityData != null) {
        print('🔍 ReaderScreen: 🎯 Found visibility tracking data: $visibilityData');
        
        if (_scrollCtrl.hasClients && _chapterImages.isNotEmpty) {
          final targetIndex = visibilityData['itemIndex'] as int;
          final localOffset = visibilityData['localOffset'] as double;
          
          print('🔍 ReaderScreen: 🎯 Restoring to visible item: $targetIndex, Local offset from item top: ${localOffset.toStringAsFixed(1)}');
          
          // Validate that the target position is achievable with current content
          final currentMaxScrollExtent = _scrollCtrl.position.maxScrollExtent;
          final approximateItemHeight = 400.0; // Use approximate for validation
          final targetItemPosition = targetIndex * approximateItemHeight;
          final finalTargetPosition = targetItemPosition + localOffset;
          
          print('🔍 ReaderScreen: 🎯 Validation - Target item position: ${targetItemPosition.toStringAsFixed(1)}');
          print('🔍 ReaderScreen: 🎯 Validation - Final target position: ${finalTargetPosition.toStringAsFixed(1)}');
          print('🔍 ReaderScreen: 🎯 Validation - Available maxScrollExtent: ${currentMaxScrollExtent.toStringAsFixed(1)}');
          
          // Check if content is ready for this restoration
          if (currentMaxScrollExtent < finalTargetPosition * 0.8) {
            print('🔍 ReaderScreen: ⏳ Content not ready for restoration - MaxScrollExtent too small');
            print('🔍 ReaderScreen: 🔄 Waiting for content to be fully ready...');
            
            // Wait for content to be ready
            await Future.delayed(const Duration(milliseconds: 1000));
            
            // Check again
            final newMaxScrollExtent = _scrollCtrl.position.maxScrollExtent;
            print('🔍 ReaderScreen: 🔄 After wait - MaxScrollExtent: ${newMaxScrollExtent.toStringAsFixed(1)}');
            
            if (newMaxScrollExtent < finalTargetPosition * 0.8) {
              print('🔍 ReaderScreen: ⚠️ Content still not ready, using fallback restoration');
              await _restoreScrollPositionFallback();
              return;
            }
          }
          
          // Use Sliver item navigation: jump to the specific item first, then apply local offset
          // This is much cleaner than calculating global scroll positions
          
          // Step 1: Jump to the target item (this will position the item at the top of the viewport)
          print('🔍 ReaderScreen: 🎯 Step 1: Jumping to item $targetIndex at position ${targetItemPosition.toStringAsFixed(1)}');
          
          _scrollCtrl.jumpTo(targetItemPosition);
          
          // Step 2: Wait a frame for the jump to complete, then apply the local offset
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              // Now apply the local offset within that item
              final currentPosition = _scrollCtrl.offset;
              final adjustedPosition = currentPosition + localOffset;
              
              print('🔍 ReaderScreen: 🎯 Step 2: Current position: ${currentPosition.toStringAsFixed(1)}, Applying local offset: ${localOffset.toStringAsFixed(1)}');
              print('🔍 ReaderScreen: 🎯 Step 2: Final adjusted position: ${adjustedPosition.toStringAsFixed(1)}');
              
              // Jump to the final position
              _scrollCtrl.jumpTo(adjustedPosition);
              
              print('🔍 ReaderScreen: ✅ Sliver item navigation + local offset restoration complete');
            }
          });
          
          return;
        }
      }
      
      // Fallback to traditional scroll offset restoration
      print('🔍 ReaderScreen: Falling back to traditional scroll offset restoration...');
      await _restoreScrollPositionFallback();
      
    } catch (e) {
      print('🔍 ReaderScreen: ❌ Error restoring scroll position: $e');
      // Try fallback restoration
      await _restoreScrollPositionFallback();
    }
  }

  // Fallback scroll restoration using traditional scroll offset
  Future<void> _restoreScrollPositionFallback() async {
    try {
      print('🔍 ReaderScreen: Querying database for chapter reading progress...');
      final progress = await _databaseHelper.getChapterReadingProgress(widget.chapterUrl);
      
      if (progress != null) {
        print('🔍 ReaderScreen: Database returned chapter progress data: $progress');
        
        if (progress['scroll_offset'] != null) {
          final savedOffset = progress['scroll_offset'] as double;
          final savedTotalPages = progress['total_pages'] as int;
          
          print('🔍 ReaderScreen: Found saved progress - Offset: ${savedOffset.toStringAsFixed(1)}, Total: $savedTotalPages');
          print('🔍 ReaderScreen: Current ScrollController state - HasClients: ${_scrollCtrl.hasClients}, CurrentOffset: ${_scrollCtrl.offset}, MaxScrollExtent: ${_scrollCtrl.position.maxScrollExtent}');
          
          if (_scrollCtrl.hasClients && savedOffset > 0) {
            // Content is already ready, so maxScrollExtent should be stable
            final maxScrollExtent = _scrollCtrl.position.maxScrollExtent;
            
            if (savedOffset <= maxScrollExtent) {
              print('🔍 ReaderScreen: ✅ Using exact saved offset: ${savedOffset.toStringAsFixed(1)}');
              _scrollCtrl.jumpTo(savedOffset);
              print('🔍 ReaderScreen: ✅ Scroll offset restored successfully');
            } else {
              print('🔍 ReaderScreen: ⚠️ Saved offset exceeds maxScrollExtent, clamping');
              _scrollCtrl.jumpTo(maxScrollExtent);
            }
            
            // Verify the jump worked
            await Future.delayed(const Duration(milliseconds: 500));
            print('🔍 ReaderScreen: After jump - Current offset: ${_scrollCtrl.offset}, Expected: ${savedOffset.toStringAsFixed(1)}');
            print('🔍 ReaderScreen: ✅ Fallback restoration complete - normal scroll tracking resumed');
          } else {
            print('🔍 ReaderScreen: ❌ Cannot jump - HasClients: ${_scrollCtrl.hasClients}, SavedOffset: $savedOffset');
          }
        } else {
          print('🔍 ReaderScreen: No scroll_offset found in chapter progress data');
        }
      } else {
        print('🔍 ReaderScreen: No chapter progress data found in database');
      }
    } catch (e) {
      print('🔍 ReaderScreen: ❌ Error in fallback restoration: $e');
    }
  }

  // Load visibility tracking data from SharedPreferences
  Future<Map<String, dynamic>?> _loadVisibilityTrackingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'visibility_${widget.chapterUrl}';
      final dataString = prefs.getString(key);
      
      if (dataString != null) {
        // Parse the data string back to a map
        // Note: This is a simple approach - in production you might want to use JSON
        final data = <String, dynamic>{};
        final regex = RegExp(r'(\w+): ([^,}]+)');
        final matches = regex.allMatches(dataString);
        
        for (final match in matches) {
          final key = match.group(1);
          final value = match.group(2);
          if (key != null && value != null) {
            if (key == 'itemIndex' || key == 'timestamp') {
              data[key] = int.tryParse(value) ?? 0;
            } else if (key == 'localOffset') {
              data[key] = double.tryParse(value) ?? 0.0;
            }
          }
        }
        
        print('🔍 ReaderScreen: ✅ Loaded visibility tracking data: $data');
        return data;
      }
    } catch (e) {
      print('🔍 ReaderScreen: ❌ Error loading visibility tracking data: $e');
    }
    return null;
  }

  Future<void> _loadChapter() async {
    print('🔍 ReaderScreen: _loadChapter called');
    print('🔍 ReaderScreen: Chapter URL: ${widget.chapterUrl}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if database needs upgrade first
      if (await _databaseHelper.needsUpgrade()) {
        print('🔍 ReaderScreen: Database upgrade needed, forcing upgrade...');
        await _databaseHelper.forceDatabaseUpgrade();
        print('🔍 ReaderScreen: Database upgrade completed');
      }

      // ALWAYS check for chapter-specific progress first (NEW - ensures offset restoration)
      print('🔍 ReaderScreen: Checking for chapter-specific progress...');
      final chapterProgress = await _databaseHelper.getChapterReadingProgress(widget.chapterUrl);
      
      if (chapterProgress != null && chapterProgress['scroll_offset'] != null) {
        final savedOffset = chapterProgress['scroll_offset'] as double;
        print('🔍 ReaderScreen: 🎯 Found chapter-specific progress - Offset: ${savedOffset.toStringAsFixed(1)}');
        
        // Check if this chapter has cached images
        final hasCachedImages = await _databaseHelper.hasCachedChapterImages(widget.chapterUrl);
        
        if (hasCachedImages) {
          // Load from database cache + restore scroll position
          print('🔍 ReaderScreen: 🗄️ Smart Loading Decision: Loading from database cache');
          print('🔍 ReaderScreen: 📖 Reason: Chapter has cached images AND saved progress');
          await _loadChapterFromDatabase(widget.chapterUrl);
          return; // Exit early, don't load from network
        } else {
          print('🔍 ReaderScreen: 📖 Smart Loading Decision: Loading from network');
          print('🔍 ReaderScreen: 📖 Reason: Chapter has saved progress but no cached images');
        }
      } else {
        print('🔍 ReaderScreen: 📖 No chapter-specific progress found, checking comic-level progress...');
        
        // Fallback: Check comic-level progress for smart loading decisions
        if (_comicDetailUrl != null) {
          final comicProgress = await _databaseHelper.getReadingProgress(_comicDetailUrl!);
          
          if (comicProgress != null && comicProgress['scroll_offset'] != null) {
            final savedOffset = comicProgress['scroll_offset'] as double;
            final savedChapterUrl = comicProgress['last_chapter_url'] as String?;
            
            print('🔍 ReaderScreen: Found comic-level progress - Offset: ${savedOffset.toStringAsFixed(1)}, Chapter: $savedChapterUrl');
            
            if (savedOffset > 0 && savedChapterUrl != null && savedChapterUrl.isNotEmpty) {
              // Check if the saved chapter actually has cached images
              final hasCachedImages = await _databaseHelper.hasCachedChapterImages(savedChapterUrl);
              
              if (hasCachedImages) {
                // User has reading progress AND cached images - load from database
                print('🔍 ReaderScreen: 🗄️ Smart Loading Decision: Loading saved chapter from database');
                print('🔍 ReaderScreen: 📖 Reason: User has reading progress (offset: ${savedOffset.toStringAsFixed(1)}) AND cached images available');
                await _loadChapterFromDatabase(widget.chapterUrl);
                return; // Exit early, don't load from network
              } else {
                print('🔍 ReaderScreen: 📖 Smart Loading Decision: Loading from network');
                print('🔍 ReaderScreen: 📖 Reason: User has reading progress but no cached images available');
              }
            } else {
              print('🔍 ReaderScreen: 📖 Smart Loading Decision: Loading from network');
              print('🔍 ReaderScreen: 📖 Reason: No valid comic-level progress (offset: ${savedOffset.toStringAsFixed(1)}, chapter: $savedChapterUrl)');
            }
          } else {
            print('🔍 ReaderScreen: 📖 Smart Loading Decision: Loading from network');
            print('🔍 ReaderScreen: 📖 Reason: No comic-level progress found in database');
          }
        } else {
          print('🔍 ReaderScreen: 📖 Smart Loading Decision: Loading from network');
          print('🔍 ReaderScreen: 📖 Reason: No comic detail URL available');
        }
      }

      // Load chapter from network (first time reading or no saved progress)
      print('🔍 ReaderScreen: 🌐 Loading chapter from network...');
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

  // Load chapter from database (cached data)
  Future<void> _loadChapterFromDatabase(String chapterUrl) async {
    try {
      print('🔍 ReaderScreen: Loading cached chapter data for: $chapterUrl');
      
      // Try to load images from database cache first
      final cachedImages = await _databaseHelper.getCachedChapterImages(chapterUrl);
      
      if (cachedImages.isNotEmpty) {
        setState(() {
          _chapterImages = cachedImages.map((imageData) {
            return PageItem(
              imageUrl: imageData['url'] as String,
              chapterIndex: imageData['order'] as int,
            );
          }).toList();
          
          _isLoading = false;
          _errorMessage = null;
        });
        
        print('🔍 ReaderScreen: 🗄️ Found ${_chapterImages.length} cached images in database');
        print('🔍 ReaderScreen: ✅ Chapter loaded from database cache');
        
        // Wait for content to be ready, then show reading screen
        _waitForContentReady();
        
      } else {
        print('🔍 ReaderScreen: 📖 No cached images found, falling back to network');
        // Fall back to network loading if no cached images
        await _loadChapterFromNetwork();
      }
      
    } catch (e) {
      print('🔍 ReaderScreen: Error loading cached chapter: $e, falling back to network');
      // Fall back to network loading if database loading fails
      await _loadChapterFromNetwork();
    }
  }

  // Load chapter from network (fresh data)
  Future<void> _loadChapterFromNetwork() async {
    print('🔍 ReaderScreen: Loading fresh chapter from network: ${widget.chapterUrl}');
    
    // Clear existing images
    setState(() {
      _chapterImages.clear();
    });

    // Load chapter with progressive loading and data caching
    final List<String> imageUrls = [];
    await NetTruyenService().fetchChapterPagesWithCallback(
      widget.chapterUrl,
      onImageFound: (imageUrl) {
        print('🔍 ReaderScreen: Image found: $imageUrl');
        imageUrls.add(imageUrl);
      },
    );

    print('🔍 ReaderScreen: Network chapter loading completed. Total images: ${imageUrls.length}');
    
    // FIRST: Download all images to database
    if (imageUrls.isNotEmpty) {
      try {
        print('🔍 ReaderScreen: Downloading images to database first...');
        
        // Prepare image data for caching
        final List<Map<String, dynamic>> imageDataList = [];
        
        for (int i = 0; i < imageUrls.length; i++) {
          final imageUrl = imageUrls[i];
          
          // Download image data for caching
          try {
            final response = await http.get(
              Uri.parse(imageUrl),
              headers: {'Referer': await _getCurrentDomainForHeaders()},
            );
            
            if (response.statusCode == 200) {
              imageDataList.add({
                'url': imageUrl,
                'data': response.bodyBytes,
                'width': null, // Will be determined when displayed
                'height': null, // Will be determined when displayed
              });
              print('🔍 ReaderScreen: ✅ Image downloaded to database: $imageUrl (${response.bodyBytes.length} bytes)');
            }
          } catch (e) {
            print('🔍 ReaderScreen: ❌ Error downloading image data for caching: $imageUrl, error: $e');
          }
        }
        
        if (imageDataList.isNotEmpty) {
          await _databaseHelper.cacheChapterImages(widget.chapterUrl, imageDataList);
          print('🔍 ReaderScreen: ✅ All images cached in database successfully');
        }
      } catch (e) {
        print('🔍 ReaderScreen: ❌ Error caching chapter images with data: $e');
      }
    }
    
    // SECOND: Now load from database (ensuring database-first approach)
    print('🔍 ReaderScreen: Loading images from database after caching...');
    await _loadChapterFromDatabase(widget.chapterUrl);
    
    // Note: _loadChapterFromDatabase will call _waitForContentReady()
    // which will handle showing the reading screen and restoring scroll
  }

  // Simple display pages getter
  List<PageItem> get _displayPages => _chapterImages;

  // Helper to build a single page widget for SuperSliverList
  Widget _buildPageWidget(int index) {
    final page = _chapterImages[index];
    
              return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: CachedNetworkImage(
        imageUrl: page.imageUrl,
        httpHeaders: {'Referer': AppConstants.PRIMARY_DOMAIN},
        placeholder: (context, url) => Container(
          height: 400,
                color: Colors.grey[300],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...'),
              ],
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
                  height: 200,
          color: Colors.red[100],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                SizedBox(height: 8),
                Text('Failed to load image'),
              ],
            ),
          ),
        ),
        fit: BoxFit.contain,
        width: double.infinity,
        // Use fadeInDuration: Duration.zero to disable placeholder fade animations
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        ),
      );
    }

  // Wait for content to be ready, then show reading screen
  Future<void> _waitForContentReady() async {
    print('🔍 ReaderScreen: Waiting for content to be ready...');
    
    // Wait for images to fully render
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check if content is stable and ready
    int attempts = 0;
    double? lastMaxScrollExtent;
    
    while (attempts < 30 && _scrollCtrl.hasClients) {
      final currentMaxScrollExtent = _scrollCtrl.position.maxScrollExtent;
      print('🔍 ReaderScreen: Content check attempt $attempts - MaxScrollExtent: ${currentMaxScrollExtent.toStringAsFixed(1)}');
      
      // Check if content is stable AND large enough for restoration
      if (lastMaxScrollExtent != null && (currentMaxScrollExtent - lastMaxScrollExtent).abs() < 5) {
        // Content is stable, now check if it's large enough
        final expectedMinHeight = 17 * 400.0; // 17 items * 400px each = 6800px minimum
        if (currentMaxScrollExtent >= expectedMinHeight * 0.8) { // Allow 20% tolerance
          print('🔍 ReaderScreen: ✅ Content is stable and large enough at ${currentMaxScrollExtent.toStringAsFixed(1)} (expected: ${expectedMinHeight.toStringAsFixed(1)})');
          break;
        } else {
          print('🔍 ReaderScreen: ⏳ Content stable but too small: ${currentMaxScrollExtent.toStringAsFixed(1)} < ${(expectedMinHeight * 0.8).toStringAsFixed(1)}');
        }
      }
      
      lastMaxScrollExtent = currentMaxScrollExtent;
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }
    
    // Now content is ready, show the screen and restore scroll
    setState(() {
      _isContentReady = true;
    });
    
    print('🔍 ReaderScreen: 🎉 Content is ready, showing reading screen');
    
    // Restore scroll position now that content is fully loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollPosition();
    });
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

  Widget _buildShimmerLoading() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Header shimmer
          Container(
            height: 100,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[600]!,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          // Content shimmer (multiple shimmer bars for images)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  height: 400 + (index * 30), // Varying heights like real images
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                );
              },
            ),
          ),
        ],
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
          print('🔍 ReaderScreen: 🚪 PopScope triggered - user is leaving');
          _saveProgressOnExit();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,

        body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        controller: _scrollCtrl,
          slivers: [

            // Collapsible page indicator - shows when scrolling up, hides when scrolling down

            // Chapter pages with SuperSliverList for better page awareness
            SuperSliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  return _buildPageWidget(index);
                },
                childCount: _chapterImages.length,
              ),
            ),
          ],
        ),
        floatingActionButton: _buildPageNavigationFAB(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 ReaderScreen: build called');
    print('🔍 ReaderScreen: _isLoading: $_isLoading');
    print('🔍 ReaderScreen: _isContentReady: $_isContentReady');
    print('🔍 ReaderScreen: _displayPages.length: ${_displayPages.length}');

    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    if (!_isContentReady) {
      return _buildShimmerLoading(); // Show shimmer until content is ready
    }

    return _buildMainReadingScreen();
  }
}
