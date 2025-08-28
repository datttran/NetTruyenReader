// lib/screens/reader_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../services/nettruyen_service.dart';
import '../services/database_helper.dart';
import '../constants/app_constants.dart';
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
    final threshold = 0.1;
    final smoothOpacity = opacity < threshold ? 0.0 : opacity;
    
    return AnimatedOpacity(
      opacity: smoothOpacity,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
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
  String? _errorMessage;
  
  // Page tracking variables
  Timer? _debounceTimer;
  int _currentPage = 1;
  double _lastSavedOffset = 0.0;
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
    
    // Extract comic detail URL from chapter URL
    _extractComicDetailUrl();
    
    // Setup scroll listener for page tracking and progress saving
    _setupScrollListener();
    
    _loadChapter();
  }

  // Extract comic detail URL from chapter URL
  void _extractComicDetailUrl() {
    try {
      // Example: https://nettruyenvia.com/truyen-tranh/one-piece/chuong-1158
      // We want: https://nettruyenvia.com/truyen-tranh/one-piece
      final uri = Uri.parse(widget.chapterUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2) {
        _comicDetailUrl = '${uri.scheme}://${uri.host}/${pathSegments[0]}/${pathSegments[1]}';
        print('🔍 ReaderScreen: Extracted comic detail URL: $_comicDetailUrl');
      }
    } catch (e) {
      print('❌ ReaderScreen: Error extracting comic detail URL: $e');
    }
  }

  // Setup scroll listener for page tracking and progress saving
  void _setupScrollListener() {
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients && _chapterImages.isNotEmpty) {
        final offset = _scrollCtrl.offset;
        
        // Simple approach: calculate current page based on scroll progress through total content
        // We know exactly how many pages we fetched, so use that as the total
        final totalHeight = _scrollCtrl.position.maxScrollExtent;
        final progress = offset / totalHeight;
        final currentPage = (progress * _chapterImages.length).round().clamp(1, _chapterImages.length);
        
        // Only update if page actually changed
        if (_currentPage != currentPage) {
          setState(() {
            _currentPage = currentPage;
          });
        }
        
        // Save progress with debouncing
        _saveProgressDebounced(offset, _currentPage);
      }
    });
  }

  // Throttled progress saving to avoid excessive database writes
  void _saveProgressDebounced(double offset, int page) {
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    // Only save if there's significant change (more than 100 pixels or page change)
    if ((offset - _lastSavedOffset).abs() < 100 && page == _currentPage) return;
    
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _saveScrollProgress(offset, page);
      _lastSavedOffset = offset;
    });
  }

  // Save scroll progress to database
  Future<void> _saveScrollProgress(double offset, int page) async {
    if (_comicDetailUrl == null) return;
    
    try {
      await _databaseHelper.saveScrollProgress(
        comicDetailUrl: _comicDetailUrl!,
        currentPage: page,
        scrollOffset: offset,
        totalPages: _chapterImages.length,
      );
      print('✅ ReaderScreen: Scroll progress saved - Page: $page, Offset: ${offset.toStringAsFixed(1)}');
    } catch (e) {
      print('❌ ReaderScreen: Error saving scroll progress: $e');
    }
  }

  @override
  void dispose() {
    // Save current reading progress before leaving
    _saveCurrentPageProgress();
    
    _debounceTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Save current page progress when leaving the chapter
  void _saveCurrentPageProgress() {
    if (_comicDetailUrl != null && _currentPage > 0 && _chapterImages.isNotEmpty) {
      print('🔍 ReaderScreen: Saving current page progress: page $_currentPage of ${_chapterImages.length}');
      
      // Save the current page for this specific chapter
      _databaseHelper.saveScrollProgress(
        comicDetailUrl: _comicDetailUrl!,
        currentPage: _currentPage,
        scrollOffset: _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0,
        totalPages: _chapterImages.length,
      );
      
      print('🔍 ReaderScreen: ✅ Current page progress saved');
    }
  }

  // Restore scroll position from saved progress
  Future<void> _restoreScrollPosition() async {
    if (_comicDetailUrl == null) return;
    
    try {
      final progress = await _databaseHelper.getReadingProgress(_comicDetailUrl!);
      if (progress != null && progress['current_page'] != null) {
        final savedPage = progress['current_page'] as int;
        final savedOffset = progress['scroll_offset'] as double? ?? 0.0;
        
        print('🔍 ReaderScreen: Found saved progress - Page: $savedPage, Offset: $savedOffset');
        
        // Jump to the latest page read
        if (savedPage > 1 && _chapterImages.isNotEmpty) {
          // Calculate the target scroll position for the saved page
          final progress = (savedPage - 1) / (_chapterImages.length - 1);
          final targetOffset = _scrollCtrl.position.maxScrollExtent * progress;
          
          // Update current page state
          setState(() {
            _currentPage = savedPage;
          });
          
          // Jump to the target position
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(targetOffset);
            print('🔍 ReaderScreen: ✅ Jumped to saved page $savedPage at offset ${targetOffset.toStringAsFixed(1)}');
          }
        } else {
          // If no saved page or page 1, just restore scroll offset
          if (_scrollCtrl.hasClients && savedOffset > 0) {
            _scrollCtrl.jumpTo(savedOffset);
            print('🔍 ReaderScreen: ✅ Restored scroll offset: ${savedOffset.toStringAsFixed(1)}');
          }
        }
      }
    } catch (e) {
      print('🔍 ReaderScreen: ❌ Error restoring scroll position: $e');
    }
  }

  Future<void> _loadChapter() async {
    print('🔍 ReaderScreen: _loadChapter called');
    print('🔍 ReaderScreen: Chapter URL: ${widget.chapterUrl}');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 ReaderScreen: Starting to fetch chapter pages...');
      // Load chapter with progressive loading
      await NetTruyenService().fetchChapterPagesWithCallback(
        widget.chapterUrl,
        onImageFound: (imageUrl) {
          print('🔍 ReaderScreen: Image found: $imageUrl');
          // Add each image as it's found for progressive display
          final pageItem = PageItem(imageUrl: imageUrl, chapterIndex: 0);
          setState(() {
            _chapterImages.add(pageItem);
          });
        },
      );

      print('🔍 ReaderScreen: Chapter loading completed. Total images: ${_chapterImages.length}');
      setState(() {
        _isLoading = false;
      });
      
      // Wait for the UI to build, then restore scroll position from saved progress
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _restoreScrollPosition();
      });
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





  // Simple display pages getter
  List<PageItem> get _displayPages => _chapterImages;

  // Helper to build a single page widget for SuperSliverList
  Widget _buildPageWidget(int index) {
    final page = _chapterImages[index];
    return FutureBuilder<String>(
      future: _getCurrentDomainForHeaders(),
      builder: (context, domainSnapshot) {
        if (!domainSnapshot.hasData) {
          return Container(
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: CachedNetworkImage(
            imageUrl: page.imageUrl,
            httpHeaders: {'Referer': domainSnapshot.data!},
            placeholder: (context, url) => Container(
              height: 400,
              color: Colors.grey[300],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading page...'),
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
                    Icon(Icons.broken_image, color: Colors.red, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.red),
                    ),
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
      },
    );
  }

  // Build page indicator widget
  Widget _buildPageIndicator() {
    if (_chapterImages.isEmpty) return const SizedBox.shrink();
    
    // Calculate progress through the current chapter
    // Page 1 = 0%, Page 17 = 100%
    final chapterProgress = (_currentPage - 1) / (_chapterImages.length - 1);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.book, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Page $_currentPage of ${_chapterImages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${(chapterProgress * 100).toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar showing progress through current chapter
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.grey[800],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: chapterProgress,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build page navigation floating action button
  Widget _buildPageNavigationFAB() {
    if (_chapterImages.length <= 1) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: () {
        final newPage = _currentPage + 1;
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

  @override
  Widget build(BuildContext context) {
    print('🔍 ReaderScreen: build called');
    print('🔍 ReaderScreen: _isLoading: $_isLoading');
    print('🔍 ReaderScreen: _errorMessage: $_errorMessage');
    print('🔍 ReaderScreen: _displayPages.length: ${_displayPages.length}');
    
    if (_isLoading && _displayPages.isEmpty) {
      print('🔍 ReaderScreen: Showing loading screen');
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading chapter...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      print('🔍 ReaderScreen: Showing error screen');
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

    print('🔍 ReaderScreen: Showing main reading screen');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text(
          'Reading Chapter',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        controller: _scrollCtrl,
        slivers: [
          // Collapsible page indicator - shows when scrolling up, hides when scrolling down
          SliverPersistentHeader(
            pinned: false,
            floating: true,
            delegate: _PageIndicatorDelegate(
              child: _buildPageIndicator(),
              minHeight: 0,
              maxHeight: 100, // Slightly taller for better visibility
            ),
          ),
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
    );
  }
}
