import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/mangadex_utils.dart';
import '../models/comic.dart';

/// Example of how to use MangaDex utilities in different parts of the app
class MangaDexUsageExample {
  
  /// Example 1: In a comic card widget
  /// This shows how to enhance comic cards with HD covers
  static Widget buildEnhancedComicCard(Comic comic) {
    return FutureBuilder<String?>(
      future: MangaDexUtils.getHdCoverUrl(comic.detailUrl),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data ?? comic.imageUrl;
        final isHd = snapshot.data != null;
        
        return Card(
          child: Column(
            children: [
              // Show HD badge if using MangaDex cover
              if (isHd)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.green,
                  child: const Text(
                    'HD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Display the image
              AspectRatio(
                aspectRatio: 2/3,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.error)),
                  ),
                ),
              ),
              
              // Comic title
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  comic.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Example 2: In a detail screen header
  /// This shows how to get HD covers for detail screens
  static Widget buildHdCoverHeader(Comic comic) {
    return FutureBuilder<String?>(
      future: MangaDexUtils.getHdCoverUrl(comic.detailUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 300,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        final imageUrl = snapshot.data ?? comic.imageUrl;
        final isHd = snapshot.data != null;
        
        return Stack(
          children: [
            // Cover image
            AspectRatio(
              aspectRatio: 2/3,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.error, size: 50)),
                ),
              ),
            ),
            
            // HD badge overlay
            if (isHd)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'HD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  
  /// Example 3: In a search result
  /// This shows how to enhance search results with HD covers
  static Widget buildHdSearchResult(Comic comic) {
    return FutureBuilder<String?>(
      future: MangaDexUtils.getHdCoverUrl(comic.detailUrl),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data ?? comic.imageUrl;
        final isHd = snapshot.data != null;
        
        return ListTile(
          leading: Stack(
            children: [
              SizedBox(
                width: 60,
                height: 90,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.error)),
                  ),
                ),
              ),
              
              // HD indicator
              if (isHd)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(comic.title),
          subtitle: Text('${comic.chapterCount} chương'),
        );
      },
    );
  }
  
  /// Example 4: Batch processing for multiple comics
  /// This shows how to efficiently process multiple comics
  static Future<List<String?>> getBatchHdCovers(List<Comic> comics) async {
    final futures = comics.map((comic) => 
      MangaDexUtils.getHdCoverUrl(comic.detailUrl)
    ).toList();
    
    return await Future.wait(futures);
  }
  
  /// Example 5: Conditional HD display
  /// This shows how to conditionally show HD content
  static Widget buildConditionalHdDisplay(Comic comic) {
    return FutureBuilder<String?>(
      future: MangaDexUtils.getHdCoverUrl(comic.detailUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // We have an HD cover, show it with special styling
          return _buildHdDisplay(snapshot.data!, comic);
        } else {
          // No HD cover, show standard display
          return _buildStandardDisplay(comic);
        }
      },
    );
  }
  
  static Widget _buildHdDisplay(String hdUrl, Comic comic) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.green,
            child: const Text(
              '🌟 HD Cover Available',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          AspectRatio(
            aspectRatio: 2/3,
            child: CachedNetworkImage(
              imageUrl: hdUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildStandardDisplay(Comic comic) {
    return AspectRatio(
      aspectRatio: 2/3,
      child: CachedNetworkImage(
        imageUrl: comic.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Center(child: Icon(Icons.error)),
        ),
      ),
    );
  }
}
