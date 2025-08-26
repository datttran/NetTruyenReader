// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:card_loading/card_loading.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import '../providers/font_provider.dart';
import '../widgets/custom_comic_card.dart';

import 'genre_comics_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Comic>? initialComics;
  final List<Comic>? initialTopComics;
  final String? initialDomain; // Add domain parameter

  const HomeScreen({
    super.key, 
    this.initialComics, 
    this.initialTopComics,
    this.initialDomain,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Comic> _allComics = []; // Changed from final
  List<Comic> _displayComics = []; // Changed from final
  List<Comic> _filteredComics = []; // Comics filtered by selected genre
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 12;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  String? _lastUsedDomain;

  // Genre filtering state
  String _selectedGenre = 'Phổ biến'; // Default to popular
  String? _selectedGenrePath;
  bool _isFilteringByGenre = false;

  // Genre caching
  final Map<String, List<Comic>> _genreCache = {};
  final Map<String, DateTime> _genreCacheTimestamps = {};
  static const Duration _cacheExpiry =
      Duration(minutes: 10); // Cache for 10 minutes

  // Popular comics caching
  static const String _popularCacheKey = 'popular';
  
  // Top comics caching
  List<Comic> _topComics = [];
  DateTime? _topComicsCacheTimestamp;
  // Use same cache expiry as main grid for consistency
  bool _isLoadingTopComics = false; // Track loading state for top comics
  
  // Logo animation variables
  late AnimationController _logoAnimationController;
  late Animation<double> _logoSlideAnimation;
  late Animation<double> _logoBounceAnimation;
  late Animation<double> _thunderAnimation;
  
  // Thunder Lottie animation controller for playing 2 times
  late AnimationController _thunderLottieController;
  int _thunderPlayCount = 0;
  final int _maxThunderPlays = 1; // Play exactly 1 time
  
  // Refresh state for showing reload.json animation
  bool _showCompletionAnimation = false; // Show completion animation briefly

  // Map to store animation controllers for genre chips
  final Map<String, AnimationController> _chipAnimationControllers = {};


  @override
  void initState() {
    super.initState();

    // Initialize logo animations
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoSlideAnimation = Tween<double>(
      begin: -100.0, // Start from above
      end: 0.0,      // Slide to final position
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));

    _logoBounceAnimation = Tween<double>(
      begin: 0.0,
      end: 20.0, // Bounce up by 20 pixels
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
    ));

    _thunderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.9, 1.0, curve: Curves.easeInOut),
    ));

    // Start logo animation
    _logoAnimationController.forward();
    
    // Initialize thunder Lottie controller after logo animation completes
    _thunderLottieController = AnimationController(vsync: this);
    _thunderLottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _thunderPlayCount++;
        if (_thunderPlayCount < _maxThunderPlays) {
          _thunderLottieController.forward(from: 0.0); // Restart the animation
        } else {
          // Animation has played the desired number of times
          print('✅ Thunder animation completed after $_maxThunderPlays plays');
        }
      }
    });

    // Use initial comics if provided, otherwise load them
    if (widget.initialComics != null && widget.initialComics!.isNotEmpty) {
      _allComics = List.from(widget.initialComics!);
      _displayComics = _allComics.take(_pageSize).toList();
      _hasMore = _allComics.length > _pageSize;
      _currentPage = 1;
    } else {
      _loadMore();
    }

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMore) {
        _loadMore();
      }
    });

    _initializeLastUsedDomain();

    // Clear expired cache entries on app start
    _clearExpiredCache();
    _clearExpiredTopComicsCache();
    
          // Initialize top comics if not already loaded
      if (_topComics.isEmpty) {
        if (widget.initialTopComics != null && widget.initialTopComics!.isNotEmpty) {
          // Use preloaded top comics from loading screen
          _topComics = List.from(widget.initialTopComics!);
          _topComicsCacheTimestamp = DateTime.now();
          print('✅ HomeScreen: Using preloaded top comics (${_topComics.length} items)');
          print('✅ HomeScreen: First top comic: ${_topComics.first.title}');
        } else {
          // Fetch top comics if not preloaded
          print('🔄 HomeScreen: No preloaded top comics, fetching...');
          _fetchTopComics();
        }
      } else {
        print('✅ HomeScreen: Top comics already loaded (${_topComics.length} items)');
      }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method initializes the last used domain
  /// to track changes when returning from settings. It's essential for the auto-reload
  /// functionality to work properly.
  Future<void> _initializeLastUsedDomain() async {
    // Use initial domain from loading screen if available, otherwise fetch fresh
    if (widget.initialDomain != null) {
      _lastUsedDomain = widget.initialDomain;
      print('✅ HomeScreen: Using initial domain from loading screen: $_lastUsedDomain');
    } else {
      _lastUsedDomain = await NetTruyenService().getCurrentDomain();
      print('🔄 HomeScreen: Fetched fresh domain: $_lastUsedDomain');
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method gets the current domain for use in headers.
  /// It ensures that thumbnails are loaded with the correct Referer header.
  String _getCurrentDomainForHeaders() {
    // If we have a cached domain, use it for immediate response
    if (_lastUsedDomain != null) {
      return _lastUsedDomain!;
    }
    
    // If no cached domain, return the default fallback
    // This will be updated once _checkAndReloadIfNeeded() completes
    return 'https://nettruyen.com';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndReloadIfNeeded();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method checks if the domain has changed
  /// since the last check and triggers a content reload if needed. It's essential for
  /// the automatic content refresh functionality when returning from settings.
  Future<void> _checkAndReloadIfNeeded() async {
    final currentDomain = await NetTruyenService().getCurrentDomain();
    print('🔍 HomeScreen: Checking domain - Last: $_lastUsedDomain, Current: $currentDomain');

    if (_lastUsedDomain != null && _lastUsedDomain != currentDomain) {
      print('🔄 HomeScreen: Domain changed, triggering reload');
      _reloadContent();
    } else {
      print('✅ HomeScreen: Domain unchanged, no reload needed');
    }
    _lastUsedDomain = currentDomain;
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method completely reloads the content
  /// by clearing existing comics and triggering a fresh load. It's essential for
  /// ensuring that content from the new domain is displayed properly.
  Future<void> _reloadContent() async {
    print('🔄 HomeScreen: _reloadContent() called - clearing main comics');
    setState(() {
      _allComics.clear();
      _displayComics.clear();
      _hasMore = true;
    });
    
    // Only clear top comics cache if we don't have preloaded data
    // This prevents clearing the data that was just passed from loading screen
    if (widget.initialTopComics == null || widget.initialTopComics!.isEmpty) {
      print('🔄 HomeScreen: Clearing top comics cache (no preloaded data)');
      _clearTopComicsCache();
    } else {
      print('✅ HomeScreen: Preserving preloaded top comics (${widget.initialTopComics!.length} items)');
    }
    
    await _loadMore();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method handles thumbnail loading failures
  /// by silently removing the failed comic from both the all comics list and display list.


  String _cleanTitle(String title) {
    return title.replaceFirst(RegExp(r'^[Tt]ruyện tranh\s*'), '').trim();
  }

  /// Filter comics by selected genre
  Future<void> _filterByGenre(String genreName, String genrePath) async {
    if (_selectedGenre == genreName && _isFilteringByGenre) {
      // Same genre selected, do nothing
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedGenre = genreName;
      _selectedGenrePath = genrePath;
      _isFilteringByGenre = true;
      _currentPage = 1; // Reset to first page when filtering
    });

    // Auto-scroll to top when filtering (only if not already at top)
    if (_scrollController.hasClients && _scrollController.offset > 500) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300), // Faster scroll
            curve: Curves.easeOut, // Smoother curve
          );
        }
      });
    }

    try {
      // Check cache first
      final cachedData = _getCachedGenreData(genrePath);
      if (cachedData != null) {
        _filteredComics = cachedData;
      } else {
        final startTime = DateTime.now();
        _filteredComics =
            await NetTruyenService().fetchComicsByGenre(genrePath);
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        print(
            '🔍 Loaded ${_filteredComics.length} comics for genre $genreName in ${duration.inMilliseconds}ms');
        // Debug: Print first few comics with chapter info
        for (int i = 0; i < _filteredComics.length && i < 3; i++) {
          final comic = _filteredComics[i];
          print(
              '🔍 Genre Comic ${i + 1}: ${comic.title} - Chapter Count: ${comic.chapterCount}, Chapter Info: ${comic.chapterInfo}');
        }

        // Debug: Check if chapter data is preserved after assignment
        print(
            '🔍 After assignment - First comic chapter data: ${_filteredComics.isNotEmpty ? _filteredComics.first.chapterCount : 'No comics'}');

        // Cache the fetched data
        _cacheGenreData(genrePath, _filteredComics);
      }

      // Apply deduplication to filtered comics
      _applyDeduplicationToFiltered();

      // Show first page of filtered comics - simple and fast
      final newItems = _filteredComics.take(_pageSize).toList();

      setState(() {
        _displayComics = newItems;
        _hasMore = _filteredComics.length > _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isFilteringByGenre = false;
        _selectedGenre = 'Phổ biến';
        _selectedGenrePath = null;
      });
    }
  }

  /// Show all comics (clear genre filter)
  Future<void> _showAllComics() async {
    setState(() {
      _isLoading = true;
      _isFilteringByGenre = false;
      _selectedGenre = 'Phổ biến';
      _selectedGenrePath = null;
      _currentPage = 1; // Reset to first page when showing all comics
    });

    // Auto-scroll to top when showing all comics (only if not already at top)
    if (_scrollController.hasClients && _scrollController.offset > 500) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300), // Faster scroll
            curve: Curves.easeOut, // Smoother curve
          );
        }
      });
    }

    // Check cache first for popular comics
    final cachedPopularData = _getCachedGenreData(_popularCacheKey);
    if (cachedPopularData != null) {
      _allComics = cachedPopularData;
    } else {
      _allComics = await NetTruyenService().fetchComics();
      _applyDeduplication();

      // Cache the popular comics
      _cacheGenreData(_popularCacheKey, _allComics);
    }

    // Show first page of popular comics - simple and fast
    final newItems = _allComics.take(_pageSize).toList();

    setState(() {
      _displayComics = newItems;
      _hasMore = _allComics.length > _pageSize;
      _isLoading = false;
    });
  }

  /// Apply deduplication to filtered comics
  void _applyDeduplicationToFiltered() {
    final map = <String, Comic>{};
    for (var comic in _filteredComics) {
      final key = _cleanTitle(comic.title);
      if (!map.containsKey(key)) {
        map[key] = Comic(
          title: key,
          imageUrl: comic.imageUrl,
          detailUrl: comic.detailUrl,
          status: comic.status,
          author: comic.author,
          views: comic.views,
          genres: comic.genres,
          updateTime: comic.updateTime,
          chapterInfo: comic.chapterInfo,
          chapterCount: comic.chapterCount,
        );
      }
    }
    _filteredComics = map.values.toList();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      if (_isFilteringByGenre) {
        // Loading more filtered comics
        if (_filteredComics.isEmpty) return;

        final currentCount = _displayComics.length;
        final newItems =
            _filteredComics.skip(currentCount).take(_pageSize).toList();

        setState(() {
          _displayComics.addAll(newItems);
          _hasMore = _displayComics.length < _filteredComics.length;
        });
      } else {
        // Loading more all comics
        if (_allComics.isEmpty) {
          // Check cache first for popular comics
          final cachedPopularData = _getCachedGenreData(_popularCacheKey);
          if (cachedPopularData != null) {
            _allComics = cachedPopularData;
          } else {
            _allComics = await NetTruyenService().fetchComics();
            print('🔍 Loaded ${_allComics.length} comics from service');
            // Debug: Print first few comics with chapter info
            for (int i = 0; i < _allComics.length && i < 3; i++) {
              final comic = _allComics[i];
              print(
                  '🔍 Comic ${i + 1}: ${comic.title} - Chapter Count: ${comic.chapterCount}, Chapter Info: ${comic.chapterInfo}');
            }
            _applyDeduplication();

            // Cache the popular comics
            _cacheGenreData(_popularCacheKey, _allComics);
          }
        }

        final newItems =
            _allComics.skip(_displayComics.length).take(_pageSize).toList();

        setState(() {
          _displayComics.addAll(newItems);
          _hasMore = _displayComics.length < _allComics.length;
        });
      }

      final newItems =
          _allComics.skip(_displayComics.length).take(_pageSize).toList();

      setState(() {
        _displayComics.addAll(newItems);
        _hasMore = _displayComics.length < _allComics.length;
      });
    } catch (e) {
      // Error loading comics
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyDeduplication() {
    final map = <String, Comic>{};
    for (var comic in _allComics) {
      final key = _cleanTitle(comic.title);
      if (!map.containsKey(key)) {
        map[key] = Comic(
          title: key,
          imageUrl: comic.imageUrl,
          detailUrl: comic.detailUrl,
          status: comic.status,
          author: comic.author,
          views: comic.views,
          genres: comic.genres,
          updateTime: comic.updateTime,
          chapterInfo: comic.chapterInfo,
          chapterCount: comic.chapterCount,
        );
      }
    }
    _allComics = map.values.toList();
  }

  /// Check if cached genre data is still valid
  bool _isGenreCacheValid(String genrePath) {
    if (!_genreCache.containsKey(genrePath)) return false;

    final timestamp = _genreCacheTimestamps[genrePath];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Get cached genre data if available and valid
  List<Comic>? _getCachedGenreData(String genrePath) {
    if (_isGenreCacheValid(genrePath)) {
      return _genreCache[genrePath];
    }
    return null;
  }

  /// Cache genre data with timestamp
  void _cacheGenreData(String genrePath, List<Comic> comics) {
    _genreCache[genrePath] = comics;
    _genreCacheTimestamps[genrePath] = DateTime.now();
  }

  /// Clear cache for a specific genre
  void _clearGenreCache(String genrePath) {
    _genreCache.remove(genrePath);
    _genreCacheTimestamps.remove(genrePath);
  }

  /// Clear all expired cache entries
  void _clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _genreCacheTimestamps.entries) {
      if (now.difference(entry.value) >= _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _genreCache.remove(key);
      _genreCacheTimestamps.remove(key);
    }
  }

  /// Clear expired top comics cache
  void _clearExpiredTopComicsCache() {
    if (_topComicsCacheTimestamp != null) {
      final now = DateTime.now();
      if (now.difference(_topComicsCacheTimestamp!) >= _cacheExpiry) {
        _topComics.clear();
        _topComicsCacheTimestamp = null;
        _isLoadingTopComics = false; // Clear loading state
      }
    }
  }

  /// Clear top comics cache manually
  void _clearTopComicsCache() {
    _topComics.clear();
    _topComicsCacheTimestamp = null;
    // Don't clear loading state here - let the calling method control it
  }

  /// Refresh content (pull to refresh)
  Future<void> _onRefresh() async {
    setState(() {
      _isLoadingTopComics = true; // Set loading state BEFORE clearing cache
    });
    
    // Clear top comics cache on refresh
    _clearTopComicsCache();
    
    // Fetch fresh top comics
    _fetchTopComics();
    
    if (_isFilteringByGenre) {
      // Refresh filtered comics (clear cache and re-fetch)
      _clearGenreCache(_selectedGenrePath!);
      await _filterByGenre(_selectedGenre, _selectedGenrePath!);
    } else {
      // Refresh popular comics (clear cache and re-fetch)
      _clearGenreCache(_popularCacheKey);
      _allComics = await NetTruyenService().fetchComics();
      _applyDeduplication();

      // Cache the fresh popular comics
      _cacheGenreData(_popularCacheKey, _allComics);

      setState(() {
        _displayComics = _allComics.take(_pageSize).toList();
        _hasMore = _allComics.length > _pageSize;
        _showCompletionAnimation = true; // Show completion animation
      });
      
      // Animation will hide automatically when it completes via onLoaded callback
    }
    
    // Note: Animation will be hidden automatically when it completes via onLoaded callback
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _logoAnimationController.dispose();
    _thunderLottieController.dispose();
    
    // Dispose all chip animation controllers
    _chipAnimationControllers.forEach((_, controller) => controller.dispose());
    
    super.dispose();
  }

  /// Get the appropriate icon for a genre
  IconData _getGenreIcon(String genreName) {
    switch (genreName) {
      case 'Phổ biến':
        return Icons.trending_up;
      case 'Action':
        return Icons.flash_on;
      case 'Comedy':
        return Icons.sentiment_satisfied;
      case 'Drama':
        return Icons.theater_comedy;
      case 'Romance':
        return Icons.favorite;
      case 'Fantasy':
        return Icons.auto_awesome;
      case 'Adventure':
        return Icons.explore;
      case 'Slice of Life':
        return Icons.home;
      case 'Psychological':
        return Icons.psychology;
      default:
        return Icons.category;
    }
  }



  /// Build a genre chip with proper styling and icon
  Widget _buildGenreChip(String genreName, String genrePath) {
    final isSelected = _selectedGenre == genreName;

    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              // Main chip button
              GestureDetector(
                onTap: () {
                  // Play tap animation if controller exists
                  if (_chipAnimationControllers.containsKey(genreName)) {
                    final controller = _chipAnimationControllers[genreName]!;
                    controller.forward();
                  }
                  
                  // Handle genre selection
                  if (genreName == 'Phổ biến') {
                    _showAllComics();
                  } else {
                    _filterByGenre(genreName, genrePath);
                  }
                },
                onLongPress: () {
                  // Long press navigates to full genre comics screen
                  if (genreName != 'Phổ biến') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenreComicsScreen(
                          genreName: genreName,
                          genreUrl: genrePath,
                        ),
                      ),
                    );
                  }
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,      // shadow color
                        offset: const Offset(4, 4),     // shadow position
                        blurRadius: 0,            // no blur → hard edge
                        spreadRadius: 0,          // no extra spread
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ThemeConstants.netflixRed
                            : ThemeConstants.netflixWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getGenreIcon(genreName),
                            size: 16 * fontProvider.fontScale,
                            color: isSelected ? Colors.white : ThemeConstants.netflixRed,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            genreName,
                            style: fontProvider.getScaledTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : ThemeConstants.netflixRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Tap animation overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: Lottie.asset(
                    'assets/animations/tap.json',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    repeat: false,
                    animate: true,
                    controller: _chipAnimationControllers[genreName],
                    onLoaded: (composition) {
                      // Create animation controller for this chip
                      final controller = AnimationController(
                        duration: composition.duration,
                        vsync: this,
                      );
                      
                      // Store controller reference for this chip
                      _chipAnimationControllers[genreName] = controller;
                      
                      // Reset controller after completion
                      controller.addStatusListener((status) {
                        if (status == AnimationStatus.completed) {
                          controller.reset();
                        }
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: Colors.white,
            backgroundColor: Colors.transparent,
            strokeWidth: 0, // Hide default spinner
            child: CustomScrollView(
              controller: _scrollController,
          slivers: [
            // App Bar that hides when scrolling up
            SliverAppBar(
              stretch: true,
              

              // Always pinned - prevents image from disappearing
              expandedHeight: _getAppBarHeight(), // 20% of screen height
              backgroundColor: Colors.transparent, // Ensure no background color
              // collapsedHeight: 56,  // Removed to use Flutter's default minimum
              flexibleSpace: FlexibleSpaceBar(
                title: Consumer<FontProvider>(
                  builder: (context, fontProvider, child) {
                    final scale = fontProvider.fontScale;

                    return Container(
                      height: scale == 1.0 ? (_getAppBarHeight() / 2) : (_getAppBarHeight() / 3) * scale, // Larger container for 1.0x scale

                      child: Center(
                        child: AnimatedBuilder(
                          animation: _logoAnimationController,
                          builder: (context, child) {
                            // Combine slide and bounce animations
                            final slideOffset = _logoSlideAnimation.value;
                            final bounceOffset = _logoBounceAnimation.value;
                            
                            return Transform.translate(
                              offset: Offset(0, slideOffset + bounceOffset),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Logo as the base layer with tap to pause/start animation
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque, // Ensures background receives taps
                                    onTap: () {
                                      if (_thunderLottieController.isAnimating) {
                                        _thunderLottieController.stop(); // Stop thunder if already playing
                                        print('⏸️ Thunder animation stopped');
                                      } else if (_thunderLottieController.isCompleted) {
                                        _thunderPlayCount = 0; // Reset play count
                                        _thunderLottieController.reset(); // Reset thunder animation
                                        _thunderLottieController.forward(); // Play thunder again
                                        print('🔄 Thunder animation reset and restarted');
                                      } else {
                                        _thunderPlayCount = 0; // Reset play count
                                        _thunderLottieController.forward(); // Start thunder from beginning
                                        print('▶️ Thunder animation started');
                                      }
                                    },
                                    child: SizedBox(
                                      height: 30 *
                                          (scale *
                                              2), // Scale logo height (x2 at 1.0, x4 at 2.0)
                                      width: 45 *
                                          (scale *
                                              2), // Scale logo width (x2 at 1.0, x4 at 2.0)
                                      child: Hero(
                                        tag: 'app_logo',
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            // Debug: Print error info
                                            print('Logo loading error: $error');
                                            print('Logo stack trace: $stackTrace');
                                            // Fallback to icon if logo fails to load
                                            return Icon(
                                              Icons.auto_stories,
                                              color: Colors.white,
                                              size: 12 *
                                                  (scale *
                                                      2), // Scale fallback icon (x2 at 1.0, x4 at 2.0)
                                            );
                                          },
                                          frameBuilder: (context, child, frame,
                                              wasSynchronouslyLoaded) {
                                            print(
                                                'Logo frame loaded: frame=$frame, sync=$wasSynchronouslyLoaded');
                                            return child;
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Thunder animation overlaid on top of the logo
                                  AnimatedOpacity(
                                    opacity: _thunderAnimation.value,  // Fades in after logo finishes
                                    duration: const Duration(milliseconds: 200),
                                                                            child: IgnorePointer( // Prevents thunder animation from blocking logo taps
                                          child: Lottie.asset(
                                            'assets/animations/RL.json',
                                            width: scale == 1.0 ? 250 : 150 * scale,   // Larger for 1.0x scale
                                            height: scale == 1.0 ? 200 : 150 * scale,  // Larger for 1.0x scale
                                            controller: _thunderLottieController,
                                            repeat: false, // Don't repeat automatically
                                            animate: true,
                                            onLoaded: (composition) {
                                              print('✅ Thunder Lottie animation loaded successfully!');
                                              print('   - Duration: ${composition.duration}');
                                              print('   - Frame rate: ${composition.frameRate}');
                                              print('   - Bounds: ${composition.bounds}');
                                              
                                              // Set the duration and start the animation
                                              _thunderLottieController.duration = composition.duration;
                                              // Start thunder animation after logo animation completes
                                              Future.delayed(const Duration(milliseconds: 1200), () {
                                                if (mounted) {
                                                  _thunderLottieController.forward();
                                                }
                                              });
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              print('❌ Thunder Lottie animation failed to load:');
                                              print('   - Error: $error');
                                              print('   - Stack trace: $stackTrace');
                                              // Fallback to static icon
                                              return Icon(
                                                Icons.flash_on,
                                                color: Colors.yellow,
                                                size: 20 * scale,
                                              );
                                            },
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                background: Stack(
                  children: [
                    // Your WebP image as background - full coverage
                    Image.asset(
                      'assets/images/app_icon_collage.webp',
                      fit: BoxFit.cover, // Use cover to fill entire area
                      width: double.infinity, // Ensure full width
                      height: double.infinity, // Ensure full height
                      errorBuilder: (context, error, stackTrace) {
                        // WebP Image error - fallback to background
                        return _buildFallbackBackground();
                      },
                      // frameBuilder removed - WebP loading confirmed working
                    ),

                    // Edge vignette overlay
                    _buildGradientOverlay(),

                    Container(
                      color: Colors.black.withOpacity(.8), // 👈 change opacity & color
                    ),

                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                    if (result == true) {
                      await _checkAndReloadIfNeeded();
                    }
                  },
                ),
              ],
            ),
            // Top Comics Section
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Consumer<FontProvider>(
                        builder: (context, fontProvider, child) {
                          return Row(
                            children: [
                              Icon(
                                Icons.flash_on,
                                color: Colors.yellow,
                                size: 24 * fontProvider.fontScale,
                              )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .shimmer(
                                  duration: 1500.ms,
                                  color: Colors.orange,
                                  size: 1.5,
                                )
                                .then()
                                .shimmer(
                                  duration: 1500.ms,
                                  color: Colors.yellow,
                                  size: 1.5,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                'Truyện Nổi Bật',
                                style: fontProvider.getScaledTextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .shimmer(
                                  duration: 2000.ms,
                                  color: Colors.red,
                                  size: 2.0,
                                )
                                .then()
                                .shimmer(
                                  duration: 2000.ms,
                                  color: Colors.orange,
                                  size: 2.0,
                                )
                                .then()
                                .shimmer(
                                  duration: 2000.ms,
                                  color: Colors.yellow,
                                  size: 2.0,
                                )
                                .then()
                                .shimmer(
                                  duration: 2000.ms,
                                  color: Colors.green,
                                  size: 2.0,
                                )
                                .then()
                                .shimmer(
                                  duration: 2000.ms,
                                  color: Colors.blue,
                                  size: 2.0,
                                )
                                .then()
                                .shimmer(
                                  duration: 2000.ms,
                                  color: Colors.indigo,
                                  size: 2.0,
                                )
                                .then()
                                .shimmer(
                                  duration: 2000.ms,
                                  color: Colors.purple,
                                  size: 2.0,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Consumer<FontProvider>(
                      builder: (context, fontProvider, child) {
                        final scale = fontProvider.fontScale;
                        final cardHeight = 200 * scale; // Scale card height with font scale
                        
                        return SizedBox(
                          height: cardHeight,
                          child: _isLoadingTopComics
                              ? _buildTopComicsLoading()
                              : _topComics.isNotEmpty
                                  ? _buildTopComicsList(_topComics, scale)
                                  : _buildTopComicsEmpty(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Popular Genres Section
            SliverToBoxAdapter(
              child: Container(

                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Consumer<FontProvider>(
                          builder: (context, fontProvider, child) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                'Thể loại: $_selectedGenre',
                                style: fontProvider.getScaledTextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: false,
                        physics: const ClampingScrollPhysics(),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildGenreChip(
                                'Phổ biến', ''), // Popular tab - shows all comics
                            _buildGenreChip('Action', '/tim-truyen/action-95'),
                            _buildGenreChip('Comedy', '/tim-truyen/comedy-99'),
                            _buildGenreChip('Drama', '/tim-truyen/drama-103'),
                            _buildGenreChip('Romance', '/tim-truyen/romance-121'),
                            _buildGenreChip('Fantasy', '/tim-truyen/fantasy-100'),
                            _buildGenreChip(
                                'Adventure', '/tim-truyen/adventure-101'),
                            _buildGenreChip(
                                'Slice of Life', '/tim-truyen/slice-of-life'),
                            _buildGenreChip(
                                'Psychological', '/tim-truyen/psychological'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Comics Grid
            SliverPadding(
              padding: const EdgeInsets.only(right: 4.0),
              sliver: Consumer<FontProvider>(
                builder: (context, fontProvider, child) {
                  // Calculate number of columns based on screen size and font scale
                  final screenWidth = MediaQuery.of(context).size.width;
                  final fontScale = fontProvider.fontScale;

                  int crossAxisCount;
                  if (screenWidth < AppConstants.MOBILE_BREAKPOINT) {
                    // Mobile: 3 columns at 1.0, 2 columns at 1.5, 1 column at 2.0
                    if (fontScale == 1.0) {
                      crossAxisCount = 3;
                    } else if (fontScale == 1.5) {
                      crossAxisCount = 2;
                    } else {
                      // 2.0
                      crossAxisCount = 1;
                    }
                  } else if (screenWidth < AppConstants.TABLET_BREAKPOINT) {
                    // Tablet: 6 columns at 1.0, 4 columns at 1.5, 2 columns at 2.0
                    if (fontScale == 1.0) {
                      crossAxisCount = 6;
                    } else if (fontScale == 1.5) {
                      crossAxisCount = 4;
                    } else {
                      // 2.0
                      crossAxisCount = 2;
                    }
                  } else {
                    // Desktop: Use tablet configuration
                    if (fontScale == 1.0) {
                      crossAxisCount = 6;
                    } else if (fontScale == 1.5) {
                      crossAxisCount = 4;
                    } else {
                      // 2.0
                      crossAxisCount = 2;
                    }
                  }

                  if (_displayComics.isEmpty || _isLoading) {
                    // Loading grid with shimmer placeholders - use SliverGrid for consistency
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Card(
                            elevation: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2.0,
                                ),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.grey,
                                    Color(0xFFE0E0E0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: const Offset(4, 4),
                                    blurRadius: 0, // No blur
                                    spreadRadius: 0, // No spread
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Upper section: 85% height with grey color
                                  Flexible(
                                    flex: 17,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(8),
                                        ),
                                      ),
                                      child: CardLoading(
                                        height: double.infinity,
                                        width: double.infinity,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(8),
                                        ),
                                        cardLoadingTheme: CardLoadingTheme(
                                          colorOne: Color(0xFFF5F5F5),
                                          colorTwo: Color(0xFFE8E8E8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Lower section: 15% height with white color
                                  Flexible(
                                    flex: 3,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF0F0F0),
                                        borderRadius: BorderRadius.vertical(
                                          bottom: Radius.circular(8),
                                        ),
                                      ),
                                      child: CardLoading(
                                        height: double.infinity,
                                        width: double.infinity,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          bottom: Radius.circular(8),
                                        ),
                                        cardLoadingTheme: CardLoadingTheme(
                                          colorOne: Color(0xFFF0F0F0),
                                          colorTwo: Color(0xFFE0E0E0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _pageSize,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: _calculateOptimalAspectRatio(),
                        crossAxisSpacing: AppConstants.GRID_SPACING,
                        mainAxisSpacing: AppConstants.GRID_SPACING,
                      ),
                    );
                  } else {
                    // Loaded comics grid
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= _displayComics.length) {
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Image placeholder that takes 85% of card height (flex: 17)
                                  Flexible(
                                    flex: 17,
                                    child: Container(
                                      color: Colors.grey[300],
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return CardLoading(
                                            height: constraints.maxHeight,
                                            width: double.infinity,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  // Text placeholder that takes 15% of card height (flex: 3)
                                  Flexible(
                                    flex: 3,
                                    child: Container(
                                      color: Colors.grey[600],
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return CardLoading(
                                            height: constraints.maxHeight,
                                            width: double.infinity,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final comic = _displayComics[index];
                          return CustomComicCard(
                            comic: comic,
                            domain: _getCurrentDomainForHeaders(),
                            columnCount: 2, // Home screen uses 2 columns
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DetailScreen(comic: comic)),
                            ),
                          );
                        },
                        childCount: _displayComics.length + (_hasMore ? 1 : 0),
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: _calculateOptimalAspectRatio(),
                        crossAxisSpacing: AppConstants.GRID_SPACING,
                        mainAxisSpacing: AppConstants.GRID_SPACING,
                      ),
                    );
                  }
                },
              ),
            ),

            // Pagination widget - always show pagination controls
            SliverToBoxAdapter(
              child: _buildPagination(),
            ),
          ],
        ),
      ),
      
      // YT.json animation overlay during refresh
      // reload.json animation overlay (visible after refresh completion)
      if (_showCompletionAnimation)
        Stack(
          children: [
            // Top animation
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * .6, // Take up top 60% of screen
              child: IgnorePointer( // Allows user to interact with app underneath
                child: Lottie.asset(
                  'assets/animations/reload.json',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain, // Cover entire screen
                  repeat: false, // Play once and stop
                  animate: true,
                  onLoaded: (composition) {
                    print('✅ reload.json completion animation loaded successfully!');
                    print('   - Duration: ${composition.duration}');
                    print('   - Frame rate: ${composition.frameRate}');
                    
                    // Hide animation after it completes playing
                    Future.delayed(composition.duration, () {
                      if (mounted) {
                        setState(() {
                          _showCompletionAnimation = false;
                        });
                      }
                    });
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ reload.json completion animation failed to load: $error');
                    return const Icon(
                      Icons.check_circle,
                      size: 200,
                      color: Colors.green,
                    );
                  },
                ),
              ),
            ),
            // Bottom inverted animation

          ],
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            ),
          );
        },
        tooltip: 'Tìm kiếm truyện',
        child: const Icon(Icons.search),
      ),
    );
  }

  /// Calculate optimal aspect ratio based on screen dimensions
  double _calculateOptimalAspectRatio() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate aspect ratio based on screen proportions
    final widthRatio = screenWidth / screenHeight;

    // Adjust aspect ratio based on screen orientation and size
    if (widthRatio > 1.0) {
      // Landscape or wide screen - use wider cards
      return 0.7;
    } else if (widthRatio < 0.6) {
      // Very narrow screen (mobile portrait) - use taller cards
      return 0.6;
    } else {
      // Standard mobile portrait - use balanced aspect ratio
      return 0.65;
    }
  }

  /// Navigate to a specific page
  void _goToPage(int page) async {
    if (page < 1) return;

    setState(() {
      _currentPage = page;
      _isLoading = true;
    });

    // Auto-scroll to top when starting to load new page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });

    try {
      if (_isFilteringByGenre) {
        // Fetch comics for specific genre with page parameter
        final pageUrl = '$_selectedGenrePath?page=$page';
        final newComics = await NetTruyenService().fetchComicsByGenre(pageUrl);

        setState(() {
          _filteredComics = newComics;
          _displayComics = newComics;
          _isLoading = false;
        });
      } else {
        // Fetch popular comics with page parameter
        final pageUrl = 'https://nettruyenvia.com/?page=$page';
        final newComics = await NetTruyenService().fetchComicsFromUrl(pageUrl);

        setState(() {
          _allComics = newComics;
          _displayComics = newComics;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle error
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Calculate app bar height as percentage of screen height, scaled with font scale
  double _getAppBarHeight() {
    // Get the current font scale from the provider
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final scale = fontProvider.fontScale;
    
    // Apply custom scaling: 1.0 = 20%, 1.5 = 30%, 2.0 = 40%
    double heightPercentage;
    if (scale == 1.0) {
      heightPercentage = 0.2;  // 20% of screen height
    } else if (scale == 1.5) {
      heightPercentage = 0.3;  // 30% of screen height
    } else if (scale == 2.0) {
      heightPercentage = 0.4;  // 40% of screen height
    } else {
      heightPercentage = 0.2;  // Fallback to 20%
    }
    
    return MediaQuery.of(context).size.height * heightPercentage;
  }

  /// Build edge vignette overlay for image
  Widget _buildGradientOverlay() {
    return Builder(
      builder: (context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final overlayColor = isDarkTheme 
            ? ThemeConstants.netflixNavy 
            : ThemeConstants.netflixRed;
        
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: [
                overlayColor.withValues(alpha: 0.5),
                overlayColor.withValues(alpha: 0.5), // Middle: light darkening
                overlayColor.withValues(alpha: 0.5), // Edge: strong darkening
                overlayColor.withValues(alpha: 0.5), // Corner: very dark
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }

  /// Build fallback background when image fails to load
  Widget _buildFallbackBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[800]!, // Dark gray instead of red
            Colors.grey[900]!, // Darker gray
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported, // Changed icon to indicate image issue
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Consumer<FontProvider>(
              builder: (context, fontProvider, child) {
                return Text(
                  'Image Not Available',
                  style: fontProvider.getScaledTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Consumer<FontProvider>(
              builder: (context, fontProvider, child) {
                return Text(
                  'Using Fallback Background',
                  style: fontProvider.getScaledTextStyle(
                    fontSize: 14,
                    color: Colors.grey[300],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build pagination widget
  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous page button
          if (_currentPage > 1)
            IconButton(
              onPressed: () => _goToPage(_currentPage - 1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Trang trước',
            ),

          // Page numbers - show current page and nearby pages
          ...List.generate(10, (index) {
            final pageNumber = index + 1;
            final isCurrentPage = pageNumber == _currentPage;

            // Show current page, first page, and pages around current
            if (pageNumber == 1 ||
                (pageNumber >= _currentPage - 1 &&
                    pageNumber <= _currentPage + 1)) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => _goToPage(pageNumber),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentPage
                          ? ThemeConstants.netflixRed
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrentPage
                            ? ThemeConstants.netflixRed
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Consumer<FontProvider>(
                      builder: (context, fontProvider, child) {
                        return Text(
                          '$pageNumber',
                          style: fontProvider.getScaledTextStyle(
                            fontSize: 14,
                            color:
                                isCurrentPage ? Colors.white : Colors.grey[700],
                            fontWeight: isCurrentPage
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            } else if (pageNumber == _currentPage - 2 ||
                pageNumber == _currentPage + 2) {
              // Show ellipsis for skipped pages
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Consumer<FontProvider>(
                  builder: (context, fontProvider, child) {
                    return Text(
                      '...',
                      style: fontProvider.getScaledTextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
              );
            } else {
              // Hide other pages
              return const SizedBox.shrink();
            }
          }),

          // Next page button (always show to allow forward navigation)
          IconButton(
            onPressed: () => _goToPage(_currentPage + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Trang tiếp',
          ),
        ],
      ),
    );
  }

  /// Fetch top comics from the specified URL with caching
  Future<List<Comic>> _fetchTopComics() async {
    // Return cached data immediately if available and valid
    if (_topComics.isNotEmpty && _topComicsCacheTimestamp != null) {
      final now = DateTime.now();
      if (now.difference(_topComicsCacheTimestamp!) < _cacheExpiry) {
        return _topComics; // Return cached data immediately
      }
    }
    
    // Set loading state only if not already loading (to avoid conflicts during refresh)
    if (!_isLoadingTopComics) {
      setState(() {
        _isLoadingTopComics = true;
      });
    }
    
    try {
      // Fetch fresh data
      final currentDomain = _getCurrentDomainForHeaders();
      final url = '$currentDomain/tim-truyen?status=&sort=10';
      final response = await NetTruyenService().fetchComicsFromUrl(url);
      
      if (response.isNotEmpty) {
        _topComics = response.take(10).toList();
        _topComicsCacheTimestamp = DateTime.now();
      }
      
      return _topComics;
    } catch (e) {
      print('Error fetching top comics: $e');
      // Return cached data if available, otherwise empty list
      return _topComics.isNotEmpty ? _topComics : [];
    } finally {
      // Clear loading state
      if (mounted) {
        setState(() {
          _isLoadingTopComics = false;
        });
      }
    }
  }

  /// Build loading state for top comics
  Widget _buildTopComicsLoading() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5, // Show 5 loading cards
      itemBuilder: (context, index) {
        return Container(
          width: 120,
          margin: const EdgeInsets.only(right: 12),
          child: Card(
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.black,
                  width: 2.0,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey,
                    Color(0xFFE0E0E0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    offset: const Offset(4, 4),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Upper section: 85% height with grey color - matching main grid
                  Flexible(
                    flex: 17,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                      child: CardLoading(
                        height: double.infinity,
                        width: double.infinity,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        cardLoadingTheme: CardLoadingTheme(
                          colorOne: Color(0xFFF5F5F5),
                          colorTwo: Color(0xFFE8E8E8),
                        ),
                      ),
                    ),
                  ),
                  // Lower section: 15% height with white color - matching main grid
                  Flexible(
                    flex: 3,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                      ),
                      child: CardLoading(
                        height: double.infinity,
                        width: double.infinity,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                        cardLoadingTheme: CardLoadingTheme(
                          colorOne: Color(0xFFF0F0F0),
                          colorTwo: Color(0xFFE0E0E0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build empty state for top comics
  Widget _buildTopComicsEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            'Không có truyện nổi bật',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Build horizontal list of top comics with scaling
  Widget _buildTopComicsList(List<Comic> comics, double scale) {
    final cardWidth = 120 * scale; // Scale card width with font scale
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: comics.length,
      itemBuilder: (context, index) {
        final comic = comics[index];
                return Container(
          width: cardWidth,
          margin: const EdgeInsets.only(right: 12),
          child: CustomComicCard(
            comic: comic,
            domain: _getCurrentDomainForHeaders(),
            columnCount: 3, // Top comics section uses 3 columns
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScreen(comic: comic),
              ),
            ),
          ),
        );
      },
    );
  }
}
