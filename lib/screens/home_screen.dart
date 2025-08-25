// lib/screens/home_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:card_loading/card_loading.dart';
import 'package:provider/provider.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';
import '../services/comic_search_delegate.dart';
import '../providers/font_provider.dart';

class HomeScreen extends StatefulWidget {
  final List<Comic>? initialComics;
  
  const HomeScreen({super.key, this.initialComics});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Comic> _allComics = []; // Changed from final
  List<Comic> _displayComics = []; // Changed from final
  List<Comic> _filteredComics = []; // Comics filtered by selected genre
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 12;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  String? _lastUsedDomain;
  final _thumbCacheManager = DefaultCacheManager();

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

  @override
  void initState() {
    super.initState();
    
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
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method initializes the last used domain
  /// to track changes when returning from settings. It's essential for the auto-reload
  /// functionality to work properly.
  Future<void> _initializeLastUsedDomain() async {
    _lastUsedDomain = await NetTruyenService().getCurrentDomain();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method gets the current domain for use in headers.
  /// It ensures that thumbnails are loaded with the correct Referer header.
  String _getCurrentDomainForHeaders() {
    return _lastUsedDomain ?? AppConstants.PRIMARY_DOMAIN;
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

    if (_lastUsedDomain != null && _lastUsedDomain != currentDomain) {
      _reloadContent();
    }
    _lastUsedDomain = currentDomain;
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method completely reloads the content
  /// by clearing existing comics and triggering a fresh load. It's essential for
  /// ensuring that content from the new domain is displayed properly.
  Future<void> _reloadContent() async {
    setState(() {
      _allComics.clear();
      _displayComics.clear();
      _hasMore = true;
    });
    await _loadMore();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method handles thumbnail loading failures
  /// by silently removing the failed comic from both the all comics list and display list.
  /// It's essential for maintaining a clean UI without broken thumbnails.
  void _onThumbnailFailed(String imageUrl) {
    setState(() {
      _allComics.removeWhere((comic) => comic.imageUrl == imageUrl);
      _displayComics.removeWhere((comic) => comic.imageUrl == imageUrl);
      _hasMore = _displayComics.length < _allComics.length;
    });
  }

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
    if (_scrollController.hasClients && _scrollController.offset > 100) {
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
      
      // Add a small delay to make shimmer effect visible
      await Future.delayed(const Duration(milliseconds: 800));
      
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
    if (_scrollController.hasClients && _scrollController.offset > 100) {
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
    
    // Add a small delay to make shimmer effect visible
    await Future.delayed(const Duration(milliseconds: 800));
    
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

  /// Refresh content (pull to refresh)
  Future<void> _onRefresh() async {
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
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Build a genre chip with proper styling
  Widget _buildGenreChip(String genreName, String genrePath) {
    final isSelected = _selectedGenre == genreName;

    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(genreName),
            onPressed: () {
              if (genreName == 'Phổ biến') {
                _showAllComics();
              } else {
                _filterByGenre(genreName, genrePath);
              }
            },
            backgroundColor: isSelected
                ? ThemeConstants.netflixRed
                : ThemeConstants.netflixRed.withValues(
                    alpha: 0.1), // Use withValues instead of withOpacity
            labelStyle: fontProvider.getScaledTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : ThemeConstants.netflixRed,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
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
                      height: (_getAppBarHeight() / 5) * scale, // Scale container height with logo
                      decoration: const BoxDecoration(color: Colors.transparent),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment
                            .center, // Left align to match menu button
                        crossAxisAlignment:
                            CrossAxisAlignment.baseline, // Align text baselines
                        textBaseline:
                            TextBaseline.alphabetic, // Use alphabetic baseline
                        children: [
                          // Your logo image with transparent background
                          ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                colors: [Colors.white, Colors.white],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: SizedBox(
                              height: 30 * (scale * 2), // Scale logo height (x2 at 1.0, x4 at 2.0)
                              width: 45 * (scale * 2), // Scale logo width (x2 at 1.0, x4 at 2.0)
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
                                      size: 12 * (scale * 2), // Scale fallback icon (x2 at 1.0, x4 at 2.0)
                                    );
                                  },
                                  frameBuilder:
                                      (context, child, frame, wasSynchronouslyLoaded) {
                                    print(
                                        'Logo frame loaded: frame=$frame, sync=$wasSynchronouslyLoaded');
                                    return child;
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
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
            // Popular Genres Section
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Consumer<FontProvider>(
                          builder: (context, fontProvider, child) {
                            return Text(
                              'Thể loại: $_selectedGenre',
                              style: fontProvider.getScaledTextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
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
                  ],
                ),
              ),
            ),
            // Comics Grid
            Consumer<FontProvider>(
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
                  } else { // 2.0
                    crossAxisCount = 1;
                  }
                } else if (screenWidth < AppConstants.TABLET_BREAKPOINT) {
                  // Tablet: 6 columns at 1.0, 4 columns at 1.5, 2 columns at 2.0
                  if (fontScale == 1.0) {
                    crossAxisCount = 6;
                  } else if (fontScale == 1.5) {
                    crossAxisCount = 4;
                  } else { // 2.0
                    crossAxisCount = 2;
                  }
                } else {
                  // Desktop: Use tablet configuration
                  if (fontScale == 1.0) {
                    crossAxisCount = 6;
                  } else if (fontScale == 1.5) {
                    crossAxisCount = 4;
                  } else { // 2.0
                    crossAxisCount = 2;
                  }
                }

                if (_displayComics.isEmpty || _isLoading) {
                  // Loading grid with shimmer placeholders - use SliverGrid for consistency
                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                                  child: CardLoading(
                                    height: double.infinity,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                              // Text placeholder that takes 15% of card height (flex: 3)
                              Flexible(
                                flex: 3,
                                child: Container(
                                  color: Colors.white,
                                  child: CardLoading(
                                    height: double.infinity,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: 6,
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
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DetailScreen(comic: comic)),
                          ),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 4,
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
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(8)),
                                          child: CachedNetworkImage(
                                            cacheManager: _thumbCacheManager,
                                            imageUrl: comic.imageUrl,
                                            httpHeaders: {
                                              'Referer':
                                                  _getCurrentDomainForHeaders()
                                            },
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
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                _onThumbnailFailed(url);
                                              });
                                              return Container(
                                                width: double.infinity,
                                                height: double.infinity,
                                                color: Colors.grey[700],
                                                child: const Center(
                                                    child: Icon(
                                                        Icons.broken_image,
                                                        size: 40)),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      // Chapter number badge on top left (shows Ch. prefix)
                                      if (comic.chapterCount != null)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.red.withValues(alpha: 0.9),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Consumer<FontProvider>(
                                              builder: (context, fontProvider,
                                                  child) {
                                                return Text(
                                                  'Ch.${comic.chapterCount}',
                                                  style: fontProvider
                                                      .getScaledTextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Text section that takes 15% of card height
                                Flexible(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: Center(
                                      child: Consumer<FontProvider>(
                                        builder: (context, fontProvider, child) {
                                          return Text(
                                            _cleanTitle(comic.title),
                                            style:
                                                fontProvider.getScaledTextStyle(
                                              fontSize: 12,
                                              color:
                                                  Theme.of(context).brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                            ),
                                            maxLines: 2,
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

            // Pagination widget - always show pagination controls
            SliverToBoxAdapter(
              child: _buildPagination(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final comic = await showSearch(
            context: context,
            delegate: ComicSearchDelegate(),
          );
          if (comic != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScreen(comic: comic),
              ),
            );
          }
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

  /// Calculate app bar height as percentage of screen height
  double _getAppBarHeight() {
    return MediaQuery.of(context).size.height * 0.2; // 20% of screen height
  }

  /// Build edge vignette overlay for image
  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            Colors.transparent, // Center: transparent
            Colors.black.withValues(alpha: 0.2), // Middle: light darkening
            Colors.black.withValues(alpha: 0.7), // Edge: strong darkening
            Colors.black.withValues(alpha: .95), // Corner: very dark
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
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
}
