import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../screens/detail_screen.dart';
import '../constants/app_constants.dart';
import '../screens/cloudflare_bypass_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
  Widget buildSuggestions(BuildContext context) {
    // no live suggestions—only on Enter
    return const Center(child: Text('Type a title and hit Enter'));
  }

  @override
  Widget buildResults(BuildContext context) {
    // This only runs when the user hits Enter/Search
    return FutureBuilder<List<Comic>>(
      future: _service.searchComics(query.trim()),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error;
          if (err.toString().contains('CloudflareException')) {
            // blocked → let user manually verify
            return Center(
              child: ElevatedButton(
                child: const Text('Verify you are human'),
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CloudflareBypassScreen(url: err.toString()),
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
                        child: FutureBuilder<String>(
                          future: _service.getCurrentDomain(),
                          builder: (context, domainSnapshot) {
                            if (!domainSnapshot.hasData) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            }
                            
                            return CachedNetworkImage(
                              cacheManager: CacheManager(Config(AppConstants.THUMB_CACHE_KEY)),
                              imageUrl: comic.imageUrl,
                              httpHeaders: {'Referer': domainSnapshot.data!},
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                            );
                          },
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
}
