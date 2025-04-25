// lib/screens/home_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/nettruyen_service.dart';
import '../models/comic.dart';
import 'detail_screen.dart';
import 'cloudflare_bypass_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _pageSize = 15;
  final ScrollController _scrollController = ScrollController();
  final CacheManager _thumbCacheManager = CacheManager(
    Config('thumbCache', maxNrOfCacheObjects: 200),
  );

  List<Comic> _allComics = [];
  List<Comic> _displayComics = [];
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMore();
      }
    });
  }

  String _cleanTitle(String title) {
    return title.replaceFirst(RegExp(r'^[Tt]ruyện tranh\s*'), '').trim();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      if (_allComics.isEmpty) {
        _allComics = await NetTruyenService().fetchComics();
        _applyDeduplication();
      }

      final newItems = _allComics
          .skip(_displayComics.length)
          .take(_pageSize)
          .toList();

      setState(() {
        _displayComics.addAll(newItems);
        _hasMore = _displayComics.length < _allComics.length;
      });
    } catch (e) {
      // TODO: show an error snackbar, etc.
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
        );
      }
    }
    _allComics = map.values.toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetTruyen Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final comic = await showSearch(
                context: context,
                delegate: ComicSearchDelegate(),
              );
              if (comic != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(comic: comic),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _allComics = await NetTruyenService().fetchComics();
          _applyDeduplication();
          setState(() {
            _displayComics = _allComics.take(_pageSize).toList();
            _hasMore = _allComics.length > _displayComics.length;
          });
        },
        child: _displayComics.isEmpty
            ? _buildShimmerGrid()
            : GridView.builder(
                controller: _scrollController,
                cacheExtent: 200,
                padding: const EdgeInsets.all(8),
                itemCount: _displayComics.length + (_hasMore ? 1 : 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  if (index >= _displayComics.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comic = _displayComics[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailScreen(comic: comic)),
                    ),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Hero(
                              tag: comic.imageUrl,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                child: CachedNetworkImage(
                                  cacheManager: _thumbCacheManager,
                                  imageUrl: comic.imageUrl,
                                  httpHeaders: const {'Referer': 'https://nettruyenvio.com'},
                                  imageBuilder: (ctx, provider) => Image(
                                    image: ResizeImage(provider, width: 200),
                                    fit: BoxFit.cover,
                                  ),
                                  placeholder: (ctx, url) => Shimmer.fromColors(
                                    baseColor: Colors.grey[800]!,
                                    highlightColor: Colors.grey[600]!,
                                    child: Container(color: Colors.grey[700]),
                                  ),
                                  errorWidget: (ctx, url, error) =>
                                      const Center(child: Icon(Icons.broken_image, size: 40)),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              comic.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _pageSize,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, __) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 4,
        child: Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          child: Container(color: Colors.grey[700]),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// SearchDelegate: only fires on Enter, shows "Verify" button if 403
/// ------------------------------------------------------------------
class ComicSearchDelegate extends SearchDelegate<Comic?> {
  final NetTruyenService _service = NetTruyenService();

  @override
  String get searchFieldLabel => 'Search comics…';

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  // Only trigger a search when user hits Enter
  @override
  void showResults(BuildContext context) {
    if (query.trim().isEmpty) return;
    super.showResults(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Comic>>(
      future: _service.searchComics(query.trim()),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error;
          if (err is CloudflareException) {
            // blocked → let user manually verify
            return Center(
              child: ElevatedButton(
                child: const Text('Verify you are human'),
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CloudflareBypassScreen(url: err.url),
                    ),
                  );
                  if (ok == true) {
                    // retry
                    showResults(context);
                  }
                },
              ),
            );
          }
          return Center(child: Text('Error: $err'));
        }

        final results = snap.data!;
        if (results.isEmpty) return const Center(child: Text('No results found.'));
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: results.length,
          itemBuilder: (_, i) {
            final comic = results[i];
            return GestureDetector(
              onTap: () {
                close(context, comic);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(comic: comic)));
              },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: CachedNetworkImage(
                          cacheManager: CacheManager(Config('thumbCache')),
                          imageUrl: comic.imageUrl,
                          httpHeaders: const {'Referer': 'https://nettruyenvio.com'},
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        comic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // no live suggestions—only on Enter
    return const Center(child: Text('Type a title and hit Enter'));
  }
}