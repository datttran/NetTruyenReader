import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:html/parser.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/nettruyen_service.dart';
import '../models/comic.dart';
import 'cloudflare_bypass_screen.dart';
import 'detail_screen.dart';
import 'package:http/http.dart' as http;



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}



Future<bool> needsCloudflareVerification(String url) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedCookie = prefs.getString('cookie') ?? '';

    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Mobile Safari/537.36',
      'Referer': 'https://nettruyenvio.com',
    };

    if (savedCookie.isNotEmpty) {
      headers['Cookie'] = savedCookie;
    }

    final response = await http.get(Uri.parse(url), headers: headers);

    print('needsCloudflareVerification -> StatusCode: ${response.statusCode}');

    if (response.statusCode != 200) {
      print('Non-200 response, may need verification');
      return true;
    }

    // Parse HTML and extract title
    final document = parse(response.body);
    final title = document.querySelector('title')?.text ?? '';

    print('Page title: $title');

    if (title.toLowerCase().contains('just a moment') ||
        title.toLowerCase().contains('checking your browser') ||
        title.toLowerCase().contains('attention required')) {
      print('Cloudflare challenge detected based on title');
      return true;
    }

    // Otherwise, normal
    return false;
  } catch (e) {
    print('Error in needsCloudflareVerification: $e');
    return false; // Default to "no need" if error happens
  }
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
    _loadCachedComics().then((_) => _loadMore());
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

  Future<void> _loadCachedComics() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('cachedComics');
    if (jsonStr != null) {
      final List data = json.decode(jsonStr) as List;
      _allComics = data
          .map((m) => Comic(
                title: m['title'],
                imageUrl: m['imageUrl'],
                detailUrl: m['detailUrl'],
              ))
          .toList();
      _applyDeduplication();
      setState(() {
        _displayComics = _allComics.take(_pageSize).toList();
        _hasMore = _allComics.length > _displayComics.length;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    if (_allComics.isEmpty) {
      try {
        _allComics = await NetTruyenService().fetchComics();
        _applyDeduplication();
        final prefs = await SharedPreferences.getInstance();
        prefs.setString(
          'cachedComics',
          json.encode(_allComics
              .map((c) => {
                    'title': c.title,
                    'imageUrl': c.imageUrl,
                    'detailUrl': c.detailUrl,
                  })
              .toList()),
        );
      } catch (e) {
        // handle error
      }
    }

    final newItems =
        _allComics.skip(_displayComics.length).take(_pageSize).toList();

    setState(() {
      _displayComics.addAll(newItems);
      _hasMore = _displayComics.length < _allComics.length;
      _isLoading = false;
    });
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
  bool _searchEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetTruyen Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final url = "https://nettruyenvio.com/tim-truyen?keyword=keyword";

              bool needsVerify = await needsCloudflareVerification(url);

              print('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX + $needsVerify');

              if (needsVerify) {
                // 🔥 Need Cloudflare solve first
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CloudflareBypassScreen(url: 'https://nettruyenvio.com/tim-truyen?keyword=keyword')),
                );


                print('result:::::::::: $result');

// After CloudflareBypassScreen closed:
                if (result == true) {
                  print('Cloudflare bypass successful! Enabling search field.');
                  setState(() {
                    _searchEnabled = true; // ✅ Re-enable your search field
                  });
                } else {
                  print('Bypass failed or user cancelled.');
                  setState(() {
                    _searchEnabled = false; // or keep disabled if failed
                  });
                };
              } else {
                showSearch(
                  context: context,
                  delegate: ComicSearchDelegate(),
                );
              }
            },
          ),
        ],
      ),
      body: _displayComics.isEmpty
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
                return _buildComicTile(comic);
              },
            ),
    );
  }

  Widget _buildComicTile(Comic comic) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailScreen(comic: comic),
        ),
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
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: CachedNetworkImage(
                    cacheManager: _thumbCacheManager,
                    imageUrl: comic.imageUrl,
                    httpHeaders: const {'Referer': 'https://nettruyenvio.com'},
                    imageBuilder: (context, provider) => Image(
                      image: ResizeImage(provider, width: 200),
                      fit: BoxFit.cover,
                    ),
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[600]!,
                      child: Container(color: Colors.grey[700]),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image, size: 40),
                    ),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

/// SearchDelegate for comics
class ComicSearchDelegate extends SearchDelegate<Comic?> {
  final NetTruyenService _service = NetTruyenService();

  @override
  String get searchFieldLabel => 'Search comics...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Comic>>(
      future: _service.searchComics(context, query),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No results found.'));
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final comic = results[index];
            return ListTile(
              leading:
                  Image.network(comic.imageUrl, width: 50, fit: BoxFit.cover),
              title: Text(comic.title),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailScreen(comic: comic),
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
    if (query.isEmpty) {
      return const Center(child: Text('Type to search.'));
    }
    return FutureBuilder<List<Comic>>(
      future: _service.searchComics(context, query),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) {
          return const Center(child: Text('No suggestions.'));
        }
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final comic = suggestions[index];
            return ListTile(
              title: Text(comic.title),
              onTap: () {
                query = comic.title;
                showResults(context);
              },
            );
          },
        );
      },
    );
  }
}
