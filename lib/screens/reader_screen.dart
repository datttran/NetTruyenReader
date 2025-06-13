// lib/screens/reader_screen.dart

import 'package:flutter/material.dart';
import '../services/nettruyen_service.dart';
import 'package:flutter/scheduler.dart';

class ReaderScreen extends StatefulWidget {
  final List<String> chapters;
  final int initialIndex;

  const ReaderScreen({
    Key? key,
    required this.chapters,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // Packed chapters for memory management
  Map<int, List<PageItem>> _chapterImages = {};
  
  // Currently loading chapter images
  List<PageItem> _currentLoadingChapter = [];
  
  // Preloaded next chapter
  List<PageItem>? _nextChapterImages;
  
  int _currentChapter = 0;
  bool _isInitialLoading = true;
  bool _isAppending = false;
  bool _isPreloadingNext = false;

  // Track chapter boundaries for accurate chapter detection
  final Map<int, int> _chapterStartIndices = {};

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialIndex;
    _scrollCtrl.addListener(_onScroll);
    _loadChapter(_currentChapter);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChapter(int chapterIndex) async {
    // If already loaded, just update current
    if (_chapterImages.containsKey(chapterIndex)) {
      setState(() {
        _currentChapter = chapterIndex;
      });
      return;
    }

    setState(() {
      _isInitialLoading = true;
      _currentLoadingChapter.clear();
      _currentChapter = chapterIndex;
    });

    // Load chapter with progressive loading
    await NetTruyenService().fetchChapterPages(
      widget.chapters[chapterIndex],
      onImageFound: (imageUrl) {
        // Add each image as it's found for progressive display
        final pageItem = PageItem(imageUrl: imageUrl, chapterIndex: chapterIndex);
        setState(() {
          _currentLoadingChapter.add(pageItem);
        });
      },
    );

    // After all images are loaded, pack them
    setState(() {
      _chapterImages[chapterIndex] = List<PageItem>.from(_currentLoadingChapter);
      _currentLoadingChapter.clear();
      _isInitialLoading = false;
    });

    // Update chapter boundaries
    _updateChapterBoundaries();

    // Clean up old chapters and preload next
    _cleanupChapters(chapterIndex);
    _preloadNextChapter(chapterIndex + 1);
  }

  void _preloadNextChapter(int nextIndex) async {
    if (_isPreloadingNext || nextIndex >= widget.chapters.length || _chapterImages.containsKey(nextIndex)) return;
    
    setState(() {
      _isPreloadingNext = true;
    });

    try {
      final imageUrls = await NetTruyenService().fetchChapterPages(widget.chapters[nextIndex]);
      final pageItems = imageUrls.map((url) => PageItem(imageUrl: url, chapterIndex: nextIndex)).toList();
      
      setState(() {
        _nextChapterImages = pageItems;
        _isPreloadingNext = false;
      });
    } catch (e) {
      setState(() {
        _isPreloadingNext = false;
      });
    }
  }

  void _cleanupChapters(int current) {
    // Keep only previous, current, and next chapter in memory
    // But be more conservative about removing chapters to prevent scroll jumps
    final keysToKeep = <int>{current - 1, current, current + 1};
    
    // Only remove chapters that are far from the current chapter
    final keysToRemove = <int>[];
    for (final key in _chapterImages.keys) {
      if (!keysToKeep.contains(key) && (key < current - 2 || key > current + 2)) {
        keysToRemove.add(key);
      }
    }
    
    for (final key in keysToRemove) {
      _chapterImages.remove(key);
    }
    
    _updateChapterBoundaries();
  }

  void _updateChapterBoundaries() {
    _chapterStartIndices.clear();
    int currentIndex = 0;
    
    final keys = _chapterImages.keys.toList()..sort();
    for (final chapterIndex in keys) {
      _chapterStartIndices[chapterIndex] = currentIndex;
      currentIndex += _chapterImages[chapterIndex]!.length;
    }
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    final cur = pos.pixels;

    // Append next chapter if near bottom
    if (!_isAppending &&
        _nextChapterImages != null &&
        cur >= pos.maxScrollExtent - 100 &&
        _currentChapter < widget.chapters.length - 1) {
      setState(() => _isAppending = true);
      _currentChapter++;
      _chapterImages[_currentChapter] = _nextChapterImages!;
      _nextChapterImages = null;

      _cleanupChapters(_currentChapter);
      _preloadNextChapter(_currentChapter + 1);
      setState(() => _isAppending = false);
    }

    // Update current chapter based on visible images - call this more frequently
    _updateCurrentChapterFromVisible();
  }

  void _updateCurrentChapterFromVisible() {
    if (_displayPages.isEmpty) return;
    
    // Get the first visible item index using a more accurate method
    final firstVisibleIndex = _getFirstVisibleIndex();
    if (firstVisibleIndex == -1) return;
    
    // Find which chapter this index belongs to
    final newChapter = _getChapterForIndex(firstVisibleIndex);
    if (_currentChapter != newChapter) {
      print('Chapter changed from $_currentChapter to $newChapter at index $firstVisibleIndex');
      
      // If we're moving to a chapter that's not loaded, load it without resetting scroll
      if (!_chapterImages.containsKey(newChapter)) {
        _loadChapterWithoutReset(newChapter);
      } else {
        setState(() {
          _currentChapter = newChapter;
        });
      }
    }
  }

  Future<void> _loadChapterWithoutReset(int chapterIndex) async {
    // Load chapter without changing the current chapter or resetting scroll
    if (_chapterImages.containsKey(chapterIndex)) return;

    setState(() {
      _isInitialLoading = true;
      _currentLoadingChapter.clear();
    });

    // Load chapter with progressive loading
    await NetTruyenService().fetchChapterPages(
      widget.chapters[chapterIndex],
      onImageFound: (imageUrl) {
        // Add each image as it's found for progressive display
        final pageItem = PageItem(imageUrl: imageUrl, chapterIndex: chapterIndex);
        setState(() {
          _currentLoadingChapter.add(pageItem);
        });
      },
    );

    // After all images are loaded, pack them
    setState(() {
      _chapterImages[chapterIndex] = List<PageItem>.from(_currentLoadingChapter);
      _currentLoadingChapter.clear();
      _isInitialLoading = false;
      _currentChapter = chapterIndex; // Update current chapter after loading
    });

    // Update chapter boundaries
    _updateChapterBoundaries();

    // Clean up old chapters and preload next
    _cleanupChapters(chapterIndex);
    _preloadNextChapter(chapterIndex + 1);
  }

  int _getFirstVisibleIndex() {
    if (_scrollCtrl.position.pixels <= 0) return 0;
    
    // Use a more accurate method to find the first visible item
    final scrollOffset = _scrollCtrl.position.pixels;
    
    // Estimate based on average item height (including padding)
    const estimatedItemHeight = 400.0; // Reduced from 500 to be more responsive
    final estimatedIndex = (scrollOffset / estimatedItemHeight).floor();
    
    return estimatedIndex.clamp(0, _displayPages.length - 1);
  }

  int _getChapterForIndex(int index) {
    // Find the chapter that contains this index
    final keys = _chapterStartIndices.keys.toList()..sort();
    
    for (int i = keys.length - 1; i >= 0; i--) {
      final chapterIndex = keys[i];
      final startIndex = _chapterStartIndices[chapterIndex]!;
      final chapterLength = _chapterImages[chapterIndex]!.length;
      
      if (index >= startIndex && index < startIndex + chapterLength) {
        return chapterIndex;
      }
    }
    
    // If not found in packed chapters, check if it's in the loading chapter
    if (_currentLoadingChapter.isNotEmpty) {
      final loadingStartIndex = _displayPages.length - _currentLoadingChapter.length;
      if (index >= loadingStartIndex) {
        return _currentLoadingChapter.first.chapterIndex;
      }
    }
    
    return _currentChapter; // Fallback
  }

  // Flatten all images for display
  List<PageItem> get _displayPages {
    final keys = _chapterImages.keys.toList()..sort();
    return [
      ...keys.expand((k) => _chapterImages[k]!),
      ..._currentLoadingChapter,
    ];
  }

  // Build the list of widgets for ListView
  List<Widget> _buildPageWidgets() {
    final widgets = <Widget>[];
    
    // Add all page images
    for (final page in _displayPages) {
      widgets.add(
        Image.network(
          page.imageUrl,
          headers: const {'Referer': 'https://nettruyenvio.com'},
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.broken_image)),
            );
          },
          fit: BoxFit.contain,
        ),
      );
    }
    
    // Add loading indicator if appending
    if (_isAppending) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading && _displayPages.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Chapter ${_currentChapter + 1}')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _buildPageWidgets(),
      ),
    );
  }
}
