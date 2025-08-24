import 'dart:async';
import 'package:flutter/material.dart'; // Needed for ImageProvider
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import '../models/comic.dart';
import '../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart'; // Fixed import path

/// Represents a single page with its chapter information
class PageItem {
  final String imageUrl;
  final int chapterIndex;

  PageItem({required this.imageUrl, required this.chapterIndex});
}

/// Thrown when Cloudflare returns a 403 on our search URL.
class CloudflareException implements Exception {
  final String url;
  CloudflareException(this.url);
}

class NetTruyenService {
  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method dynamically loads the current domain
  /// from SharedPreferences or falls back to the default domain. This is essential for
  /// the domain switching functionality to work properly.
  Future<String> getCurrentDomain() async {
    final prefs = await SharedPreferences.getInstance();
    String domain = prefs.getString('custom_domain') ?? AppConstants.PRIMARY_DOMAIN;
    
    // Ensure domain ends with trailing slash for proper URL construction
    if (!domain.endsWith('/')) {
      domain = '$domain/';
    }
    
    return domain;
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method builds the base headers for all HTTP requests.
  /// It dynamically includes the current domain as the Referer header, which is essential for
  /// bypassing Cloudflare protection and maintaining proper request context.
  Future<Map<String, String>> _getBaseHeaders() async {
    final baseHeaders = Map<String, String>.from({
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    });
    
    final currentBase = await getCurrentDomain();
    baseHeaders['Referer'] = currentBase;
    return baseHeaders;
  }

  // CRITICAL: DO NOT CHANGE THIS METHOD! HTTP approach works perfectly
  Future<List<Comic>> fetchComics() async {
    final domain = await getCurrentDomain();
    // Remove trailing slash for base URL
    final url = domain.endsWith('/') ? domain.substring(0, domain.length - 1) : domain;

    
    try {
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      

      if (response.statusCode == 200) {
        final htmlContent = response.body;
        
        final comics = _parseComicsFromHtml(htmlContent, url);
        
        return comics;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        throw Exception('Network connection failed. Please check your internet connection.');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timed out. Please try again.');
      } else {
        throw Exception('Failed to load homepage');
      }
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method parses the HTML content from the homepage
  /// and extracts comic information. It handles various edge cases and provides detailed logging
  /// for debugging purposes. The parsing logic is optimized for the current HTML structure.
  /// 
  /// ⚠️ WARNING: The image attribute priority order is CRITICAL for proper thumbnail loading.
  /// Changing the order will break thumbnail display and show default images for all comics.
  List<Comic> _parseComicsFromHtml(String htmlContent, String baseUrl) {
    final document = html.parse(htmlContent);
    
    // Try different selectors
    final itemElements = document.querySelectorAll('.item');
    final itemsElements = document.querySelectorAll('.items .item');
    final comicItemElements = document.querySelectorAll('.comic-item');
    final cardElements = document.querySelectorAll('.card');
    
    // Use the selector that finds the most elements
    final comicElements = itemsElements.isNotEmpty ? itemsElements : 
                         itemElements.isNotEmpty ? itemElements :
                         comicItemElements.isNotEmpty ? comicItemElements :
                         cardElements.isNotEmpty ? cardElements : [];
    
    final comics = <Comic>[];
    
    for (final element in comicElements) {
      try {
        final linkElement = element.querySelector('a');
        final imageElement = element.querySelector('img');
        
        if (linkElement != null && imageElement != null) {
          final href = linkElement.attributes['href'];
          final title = imageElement.attributes['alt'] ?? 'Unknown Title';
          
          // CRITICAL: DO NOT CHANGE THIS PRIORITY ORDER! The website uses lazy loading where:
          // - 'src' contains placeholder/default images (thumb-default.jpg)
          // - 'data-original' contains the REAL thumbnail URLs from CDN
          // - 'data-retries' contains backup thumbnail URLs
          // - 'data-src' contains alternative image sources
          // 
          // Using 'src' first will result in all comics showing the same default image.
          // Using 'data-original' first will show unique thumbnails for each comic.
          final imageUrl = imageElement.attributes['data-original'] ??
                          imageElement.attributes['data-retries'] ??
                          imageElement.attributes['data-src'] ??
                          imageElement.attributes['src'];
          
          // Try to extract chapter information from the comic element
          String? chapterInfo;
          int? chapterCount;
          
          // Look for chapter-related elements
          final chapterElement = element.querySelector('.chapter, .chap, .episode, .latest-chapter');
          if (chapterElement != null) {
            final chapterText = chapterElement.text?.trim();
            if (chapterText != null && chapterText.isNotEmpty) {
              chapterInfo = chapterText;
              // Try to extract chapter number from text like "Chapter 123" or "Chap 123"
              final chapterMatch = RegExp(r'[Cc]hapter?\s*(\d+)').firstMatch(chapterText);
              if (chapterMatch != null) {
                chapterCount = int.tryParse(chapterMatch.group(1) ?? '');
              }
            }
          } else {
            // Try more selectors
            final altChapterElement = element.querySelector('[class*="chapter"], [class*="chap"], [class*="episode"]');
            if (altChapterElement != null) {
              final altChapterText = altChapterElement.text?.trim();
              if (altChapterText != null && altChapterText.isNotEmpty) {
                chapterInfo = altChapterText;
                final chapterMatch = RegExp(r'[Cc]hapter?\s*(\d+)').firstMatch(altChapterText);
                if (chapterMatch != null) {
                  chapterCount = int.tryParse(chapterMatch.group(1) ?? '');
                }
              }
            }
          }
          
          // Also try to find chapter count in the title or other attributes
          if (chapterCount == null) {
            final titleMatch = RegExp(r'[Cc]hapter?\s*(\d+)').firstMatch(title);
            if (titleMatch != null) {
              chapterCount = int.tryParse(titleMatch.group(1) ?? '');
            }
          }
          
          if (href != null && imageUrl != null) {
            final fullUrl = href.startsWith('http') ? href : '$baseUrl$href';
            final fullImageUrl = imageUrl.startsWith('http') ? imageUrl : '$baseUrl$imageUrl';
            
            final comic = Comic(
              title: title.trim(),
              imageUrl: fullImageUrl,
              detailUrl: fullUrl,
              chapterInfo: chapterInfo,
              chapterCount: chapterCount,
            );
            
            comics.add(comic);

          }
        }
      } catch (e) {
        continue;
      }
    }
    
    return comics;
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method fetches the chapter list for a specific comic.
  /// It parses the HTML content from the comic detail page to extract chapter information.
  /// The method is essential for the chapter navigation functionality.
  Future<List<String>> fetchChapters(String comicUrl) async {
    try {
  
      
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(comicUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));



      if (response.statusCode == 200) {
        final htmlContent = response.body;

        
        // Check if we got blocked by Cloudflare
        if (htmlContent.contains('Just a moment') || htmlContent.contains('Checking your browser')) {

          throw Exception('CloudflareException: Chapter fetch blocked');
        }
        
        final document = html.parse(htmlContent);
        
        // Try different selectors for chapter links
        var chapterElements = document.querySelectorAll('.chapter a, .list-chapter a, .chapters a, a[href*="/chap-"]');

        
        if (chapterElements.isEmpty) {

          // Try alternative selectors
          final altElements = document.querySelectorAll('a[href*="truyen-tranh"][href*="chap"]');

          if (altElements.isNotEmpty) {
            chapterElements = altElements;
          }
        }
        
        final chapters = <String>[];
        for (final element in chapterElements) {
          final href = element.attributes['href'];
          if (href != null && href.isNotEmpty) {
            // Convert relative URLs to absolute URLs
            String fullUrl;
            if (href.startsWith('http')) {
              fullUrl = href;
            } else if (href.startsWith('/')) {
              final baseDomain = await getCurrentDomain();
              fullUrl = '$baseDomain$href';
            } else {
              final baseDomain = await getCurrentDomain();
              fullUrl = '$baseDomain/$href';
            }
            chapters.add(fullUrl);
          }
        }
        

        return chapters;
      } else {

        throw Exception('Failed to load chapters: HTTP ${response.statusCode}');
      }
    } catch (e) {

      if (e.toString().contains('CloudflareException')) {
        rethrow; // Re-throw Cloudflare exceptions for proper handling
      }
      throw Exception('Failed to load chapters: $e');
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method fetches the individual pages of a chapter.
  /// It parses the HTML content to extract image URLs and handles various error conditions.
  /// The method is essential for the chapter reading functionality.
  Future<List<String>> fetchChapterPages(String chapterUrl) async {
    try {
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(chapterUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final htmlContent = response.body;
        final document = html.parse(htmlContent);
        final imageElements = document.querySelectorAll('.page-chapter img');
        
        return imageElements
            .map((img) => img.attributes['src'] ?? '')
            .where((src) => src.isNotEmpty)
            .toList();
      } else {
        throw Exception('Failed to load chapter: HTTP ${response.statusCode}');
      }
    } catch (e) {

      throw Exception('Failed to load chapter pages');
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method fetches chapter pages with progressive loading callback.
  /// It provides real-time feedback as each image is discovered, enabling progressive UI updates.
  /// This method is essential for the smooth reading experience with loading indicators.
  Future<List<String>> fetchChapterPagesWithCallback(
    String chapterUrl, {
    Function(String imageUrl)? onImageFound,
  }) async {
    try {
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(chapterUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final htmlContent = response.body;
        final document = html.parse(htmlContent);
        final imageElements = document.querySelectorAll('.page-chapter img');
        
        final imageUrls = <String>[];
        for (final img in imageElements) {
          final src = img.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            imageUrls.add(src);
            // Call the callback for each image as it's found
            onImageFound?.call(src);
          }
        }
        
        return imageUrls;
      } else {
        throw Exception('Failed to load chapter: HTTP ${response.statusCode}');
      }
    } catch (e) {

      throw Exception('Failed to load chapter pages');
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method performs comic search using the HTTP approach.
  /// It's designed to handle basic search functionality with proper error handling.
  /// If Cloudflare blocks the request, the search will return empty results.
  Future<List<Comic>> searchComics(String keyword) async {
    try {
      final searchDomain = await getCurrentDomain();
      // Remove trailing slash from domain since we're adding a path
      final cleanDomain = searchDomain.endsWith('/') ? searchDomain.substring(0, searchDomain.length - 1) : searchDomain;
      final searchUrl = '$cleanDomain/tim-truyen?keyword=${Uri.encodeComponent(keyword)}';
      
  
      
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));



      if (response.statusCode == 200) {
        final htmlContent = response.body;

        
        // Check if we got blocked by Cloudflare
        if (htmlContent.contains('Just a moment') || htmlContent.contains('Checking your browser')) {

          throw Exception('CloudflareException: Search blocked');
        }
        
        final comics = _parseComicsFromHtml(htmlContent, searchDomain);

        return comics;
      } else {

        throw Exception('Search failed: HTTP ${response.statusCode}');
      }
    } catch (e) {

      if (e.toString().contains('CloudflareException')) {
        rethrow; // Re-throw Cloudflare exceptions for proper handling
      }
      throw Exception('Search failed: $e');
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method fetches detailed information about a specific comic.
  /// It parses the comic detail page to extract title, description, and other metadata.
  /// The method is essential for the comic information display functionality.
  Future<Map<String, dynamic>> fetchComicDetails(String comicUrl) async {
    try {
      final headers = await _getBaseHeaders();
      
      final response = await http.get(
        Uri.parse(comicUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));



      if (response.statusCode == 200) {
        final htmlContent = response.body;

        
        // Check if we got blocked by Cloudflare
        if (htmlContent.contains('Just a moment') || htmlContent.contains('Checking your browser')) {

          throw Exception('CloudflareException: Comic details fetch blocked');
        }
        
        final document = html.parse(htmlContent);
        
        // Try multiple selectors for different HTML structures
        final title = document.querySelector('.title-detail, .comic-title, h1.title, .name')?.text?.trim() ?? 'Unknown Title';
        final description = document.querySelector('.detail-content, .comic-description, .description, .summary')?.text?.trim() ?? 'No description available';
        
        // Try to extract status
        String? status;
        final statusElement = document.querySelector('.status, .tinh-trang, .comic-status');
        if (statusElement != null) {
          // Extract only the value, not the label
          String statusText = statusElement.text?.trim() ?? '';
          // Remove common label prefixes
          statusText = statusText.replaceAll(RegExp(r'^Tình trạng\s*'), '');
          statusText = statusText.replaceAll(RegExp(r'^Status\s*'), '');
          status = statusText.isNotEmpty ? statusText : null;
        }
        
        // Try to extract author
        String? author;
        final authorElement = document.querySelector('.author, .tac-gia, .comic-author');
        if (authorElement != null) {
          // Extract only the value, not the label
          String authorText = authorElement.text?.trim() ?? '';
          // Remove common label prefixes
          authorText = authorText.replaceAll(RegExp(r'^Tác giả\s*'), '');
          authorText = authorText.replaceAll(RegExp(r'^Author\s*'), '');
          author = authorText.isNotEmpty ? authorText : null;
        }
        
        // Try to extract views
        String? views;
        final viewsElement = document.querySelector('.views, .luot-xem, .comic-views');
        if (viewsElement != null) {
          // Extract only the value, not the label
          String viewsText = viewsElement.text?.trim() ?? '';
          // Remove common label prefixes
          viewsText = viewsText.replaceAll(RegExp(r'^Lượt xem\s*'), '');
          viewsText = viewsText.replaceAll(RegExp(r'^Views\s*'), '');
          views = viewsText.isNotEmpty ? viewsText : null;
        }
        
        // Try to extract genres - only from specific genre containers
        List<Genre> genres = [];
        
        // Try the specific structure first: <li class="kind row"> with genre links
        final genreContainer = document.querySelector('li.kind.row');
        if (genreContainer != null) {
          final genreLinks = genreContainer.querySelectorAll('a[href*="/tim-truyen/"]');
          if (genreLinks.isNotEmpty) {
            genres = genreLinks.map((e) {
              final name = e.text?.trim() ?? '';
              String url = e.attributes['href'] ?? '';
              // Normalize URL to always be relative (remove domain if present)
              if (url.startsWith('http')) {
                final uri = Uri.parse(url);
                url = uri.path;
              }
              return Genre(name: name, url: url);
            }).where((g) => g.name.isNotEmpty && g.url.isNotEmpty).toList();
          }
        }
        
        // Fallback to generic genre selectors if the specific structure doesn't work
        if (genres.isEmpty) {
          final genreElements = document.querySelectorAll('.genres a, .the-loai a, .comic-genres a, .category a');
          if (genreElements.isNotEmpty) {
            genres = genreElements.map((e) {
              final name = e.text?.trim() ?? '';
              String url = e.attributes['href'] ?? '';
              // Normalize URL to always be relative (remove domain if present)
              if (url.startsWith('http')) {
                final uri = Uri.parse(url);
                url = uri.path;
              }
              return Genre(name: name, url: url);
            }).where((g) => g.name.isNotEmpty && g.url.isNotEmpty).toList();
          }
        }
        
        // Only show genres if we found them from specific genre containers
        // Don't fall back to generic link searching as it can pick up navigation links
        
        // Try to extract update time
        String? updateTime;
        final timeElement = document.querySelector('.update-time, .cap-nhat, .comic-update-time');
        if (timeElement != null) {
          // Extract only the value, not the label
          String timeText = timeElement.text?.trim() ?? '';
          // Remove common label prefixes
          timeText = timeText.replaceAll(RegExp(r'^Cập nhật\s*'), '');
          timeText = timeText.replaceAll(RegExp(r'^Update\s*'), '');
          updateTime = timeText.isNotEmpty ? timeText : null;
        }
        

        
        return {
          'title': title,
          'description': description,
          'status': status,
          'author': author,
          'views': views,
          'genres': genres,
          'updateTime': updateTime,
          'url': comicUrl,
        };
      } else {

        throw Exception('Failed to load comic details: HTTP ${response.statusCode}');
      }
    } catch (e) {

      if (e.toString().contains('CloudflareException')) {
        rethrow; // Re-throw Cloudflare exceptions for proper handling
      }
      throw Exception('Failed to load comic details: $e');
    }
  }

    /// CRITICAL: DO NOT CHANGE THIS METHOD! This method updates a comic with its full details from the database.
  /// It first checks the local cache, then fetches from the network if needed, and finally saves to the database.
  /// The method is essential for the caching and performance optimization functionality.
  Future<Comic> updateComicWithDetails(Comic comic) async {
    try {
      // First, check if we have cached data in the database
      final helper = DatabaseHelper();
      final cachedComic = await helper.getComic(comic.detailUrl);
      
      // If we have cached data and it's recent (less than 1 hour old), use it
      if (cachedComic != null && 
          cachedComic.status != null && 
          cachedComic.author != null && 
          cachedComic.genres.isNotEmpty) {
        
        // Check if cache is recent (less than 1 hour old)
        final cacheAge = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(
            await helper.getComicCacheAge(comic.detailUrl) ?? 0
          )
        );
        
        if (cacheAge.inHours < 1) {
          // Use cached data - it's recent enough
          return cachedComic;
        }
      }
      
      // No recent cached data, fetch from network
      final details = await fetchComicDetails(comic.detailUrl);
      
      final updated = Comic(
        title: comic.title,
        imageUrl: comic.imageUrl,
        detailUrl: comic.detailUrl,
        status: details['status'],
        author: details['author'],
        views: details['views'],
        genres: details['genres'] ?? [],
        updateTime: details['updateTime'],
      );
      
      // Save to database (this will update existing records)
      try {
        final comicId = await helper.insertComic(updated);
      } catch (dbError) {
        // Continue even if database save fails - the data is still valid
      }

      return updated;
    } catch (e) {
      // If fetching fails, try to return cached data as fallback
      try {
        final helper = DatabaseHelper();
        final cachedComic = await helper.getComic(comic.detailUrl);
        if (cachedComic != null && 
            cachedComic.status != null && 
            cachedComic.author != null && 
            cachedComic.genres.isNotEmpty) {
          return cachedComic;
        }
      } catch (dbError) {
        // Database error, continue to fallback
      }
      
      // If no cached data available, return the original comic with empty details
      // This ensures the UI doesn't crash
      return Comic(
        title: comic.title,
        imageUrl: comic.imageUrl,
        detailUrl: comic.detailUrl,
        status: null,
        author: null,
        views: null,
        genres: [],
        updateTime: null,
      );
    }
  }

  /// Force refresh comic details from network (ignores cache)
  /// Useful for pull-to-refresh or manual refresh
  Future<Comic> forceRefreshComicDetails(Comic comic) async {
    try {
      // Always fetch fresh data from network
      final details = await fetchComicDetails(comic.detailUrl);
      
      final updated = Comic(
        title: comic.title,
        imageUrl: comic.imageUrl,
        detailUrl: comic.detailUrl,
        status: details['status'],
        author: details['author'],
        views: details['views'],
        genres: details['genres'] ?? [],
        updateTime: details['updateTime'],
      );
      
      // Save to database
      try {
        final helper = DatabaseHelper();
        final comicId = await helper.insertComic(updated);
      } catch (dbError) {
        // Continue even if database save fails
      }

      return updated;
    } catch (e) {
      // If fetching fails, try to return cached data as fallback
      try {
        final helper = DatabaseHelper();
        final cachedComic = await helper.getComic(comic.detailUrl);
        if (cachedComic != null && 
            cachedComic.status != null && 
            cachedComic.author != null && 
            cachedComic.genres.isNotEmpty) {
          return cachedComic;
        }
      } catch (dbError) {
        // Database error, continue to fallback
      }
      
      // Return original comic with empty details if all else fails
      return Comic(
        title: comic.title,
        imageUrl: comic.imageUrl,
        detailUrl: comic.detailUrl,
        status: null,
        author: null,
        views: null,
        genres: [],
        updateTime: null,
      );
    }
  }

  /// Fetches comics by genre URL (e.g., /tim-truyen/action-95)
  Future<List<Comic>> fetchComicsByGenre(String genreUrl) async {
    try {
      final currentDomain = await getCurrentDomain();
      
      // Handle both relative and absolute URLs
      String fullUrl;
      if (genreUrl.startsWith('http')) {
        fullUrl = genreUrl; // Already a full URL
      } else {
        // Remove trailing slash from domain since we're adding a path
        final cleanDomain = currentDomain.endsWith('/') ? currentDomain.substring(0, currentDomain.length - 1) : currentDomain;
        fullUrl = '$cleanDomain$genreUrl'; // Construct full URL
      }

  
      
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final htmlContent = response.body;

        
        // Parse the genre page HTML to extract comics
        final document = html.parse(htmlContent);
        
        // Use the same parsing logic as the main page
        final comics = _parseComicsFromHtml(htmlContent, currentDomain);
        
        return comics;
      } else {

        throw Exception('Failed to load genre page: HTTP ${response.statusCode}');
      }
    } catch (e) {

      if (e.toString().contains('CloudflareException')) {
        rethrow; // Re-throw Cloudflare exceptions for proper handling
      }
      throw Exception('Failed to fetch comics by genre: $e');
    }
  }

  /// Fetches comics from a specific URL (supports page parameters)
  Future<List<Comic>> fetchComicsFromUrl(String url) async {
    try {
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final htmlContent = response.body;
        
        // Use the same parsing logic as the main page
        final comics = _parseComicsFromHtml(htmlContent, url);
        
        return comics;
      } else {
        throw Exception('Failed to load page: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('CloudflareException')) {
        rethrow; // Re-throw Cloudflare exceptions for proper handling
      }
      throw Exception('Failed to fetch comics from URL: $e');
    }
  }
}

/// CRITICAL: DO NOT CHANGE THIS FUNCTION! This function fetches images with proper headers for display.
/// It ensures that images are loaded with the correct Referer header to bypass any protection mechanisms.
/// The function is essential for the image loading and display functionality.
Future<ImageProvider> fetchImageWithHeaders(String url) async {
  final netTruyenService = NetTruyenService();
  final currentDomain = await netTruyenService.getCurrentDomain();
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        ...AppConstants.DEFAULT_HEADERS,
        'Referer': currentDomain,
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return MemoryImage(response.bodyBytes);
    } else {
      throw Exception('Failed to load image: HTTP ${response.statusCode}');
    }
  } catch (e) {
    
    throw Exception('Failed to load image');
  }
}

class CustomNetworkImage extends StatelessWidget {
  final String imageUrl;
  const CustomNetworkImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: fetchImageWithHeaders(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return Image(image: snapshot.data!);
        } else if (snapshot.hasError) {
          return const Icon(Icons.error);
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}