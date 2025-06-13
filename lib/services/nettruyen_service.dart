import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart'; // Needed for ImageProvider
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';
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
    return prefs.getString('custom_domain') ?? AppConstants.PRIMARY_DOMAIN;
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
    final url = await getCurrentDomain();
    print('🔍 Fetching comics from: $url');
    
    try {
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      print('🔍 Response status: ${response.statusCode}');
      print('🔍 Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final htmlContent = response.body;
        print('🔍 HTML content length: ${htmlContent.length}');
        print('🔍 HTML preview: ${htmlContent.substring(0, 200)}...');
        
        return _parseComicsFromHtml(htmlContent, url);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        print('❌ Network error: $e');
        throw Exception('Network connection failed. Please check your internet connection.');
      } else if (e.toString().contains('TimeoutException')) {
        print('❌ Timeout error: $e');
        throw Exception('Request timed out. Please try again.');
      } else {
        print('❌ Error loading comics: $e');
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
    final document = parse(htmlContent);
    
    // Debug: Check what elements exist
    final allElements = document.querySelectorAll('*');
    print('🔍 Total HTML elements found: ${allElements.length}');
    
    // Try different selectors
    final itemElements = document.querySelectorAll('.item');
    final itemsElements = document.querySelectorAll('.items .item');
    final comicItemElements = document.querySelectorAll('.comic-item');
    final cardElements = document.querySelectorAll('.card');
    
    print('🔍 .item elements: ${itemElements.length}');
    print('🔍 .items .item elements: ${itemsElements.length}');
    print('🔍 .comic-item elements: ${comicItemElements.length}');
    print('🔍 .card elements: ${cardElements.length}');
    
    // Use the selector that finds the most elements
    final comicElements = itemsElements.isNotEmpty ? itemsElements : 
                         itemElements.isNotEmpty ? itemElements :
                         comicItemElements.isNotEmpty ? comicItemElements :
                         cardElements.isNotEmpty ? cardElements : [];
    
    print('🔍 Using selector that found ${comicElements.length} comic items');
    
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
          
          print('🔍 Raw href: $href');
          print('🔍 Raw title: $title');
          print('🔍 Raw imageUrl: $imageUrl');
          print('🔍 All image attributes: ${imageElement.attributes}');
          
          if (href != null && imageUrl != null) {
            final fullUrl = href.startsWith('http') ? href : '$baseUrl$href';
            final fullImageUrl = imageUrl.startsWith('http') ? imageUrl : '$baseUrl$imageUrl';
            
            final comic = Comic(
              title: title.trim(),
              imageUrl: fullImageUrl,
              detailUrl: fullUrl,
            );
            
            comics.add(comic);
            print('🔍 Comic: "$title" -> $fullUrl');
            print('🔍 Image: $fullImageUrl');
          }
        }
      } catch (e) {
        print('⚠️ Error parsing comic element: $e');
        continue;
      }
    }
    
    return comics;
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method fetches the chapter list for a specific comic.
  /// It uses the comic slug to construct the API URL and handles the JSON response properly.
  /// The method is essential for the chapter navigation functionality.
  Future<List<String>> fetchChapters(String comicSlug) async {
    try {
      final apiDomain = await getCurrentDomain();
      final api = Uri.parse(
        '$apiDomain/Comic/Services/ComicService.asmx/ChapterList?slug=$comicSlug',
      );
      
      final headers = await _getBaseHeaders();
      final response = await http.get(api, headers: headers).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final data = jsonData['d'] as List;
        
        final chapterDomain = await getCurrentDomain();
        final chapters = data.map<String>((e) {
          final slug = e['chapter_slug'] as String;
          return '$chapterDomain/truyen-tranh/$comicSlug/$slug';
        }).toList();
        
        return chapters;
      } else {
        throw Exception('Failed to load chapters: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching chapters: $e');
      throw Exception('Failed to load chapters');
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
        final document = parse(htmlContent);
        final imageElements = document.querySelectorAll('.page-chapter img');
        
        return imageElements
            .map((img) => img.attributes['src'] ?? '')
            .where((src) => src.isNotEmpty)
            .toList();
      } else {
        throw Exception('Failed to load chapter: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching chapter pages: $e');
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
        final document = parse(htmlContent);
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
      print('❌ Error fetching chapter pages: $e');
      throw Exception('Failed to load chapter pages');
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method performs comic search using the HTTP approach.
  /// It's designed to handle basic search functionality with proper error handling.
  /// If Cloudflare blocks the request, the search will return empty results.
  Future<List<Comic>> searchComics(String keyword) async {
    try {
      final searchDomain = await getCurrentDomain();
      final searchUrl = '${searchDomain}/tim-truyen?keyword=${Uri.encodeComponent(keyword)}';
      
      print('🔍 Searching for: $keyword at $searchUrl');
      
      final headers = await _getBaseHeaders();
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      print('🔍 Search response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final htmlContent = response.body;
        print('🔍 Search HTML content length: ${htmlContent.length}');
        
        // Check if we got blocked by Cloudflare
        if (htmlContent.contains('Just a moment') || htmlContent.contains('Checking your browser')) {
          print('❌ Search blocked by Cloudflare');
          throw Exception('CloudflareException: Search blocked');
        }
        
        final comics = _parseComicsFromHtml(htmlContent, searchDomain);
        print('🔍 Found ${comics.length} search results for: $keyword');
        return comics;
      } else {
        print('❌ Search failed with status: ${response.statusCode}');
        throw Exception('Search failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in search: $e');
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
        final document = parse(htmlContent);
        
        final title = document.querySelector('.title-detail')?.text?.trim() ?? 'Unknown Title';
        final description = document.querySelector('.detail-content')?.text?.trim() ?? 'No description available';
        
        return {
          'title': title,
          'description': description,
          'url': comicUrl,
        };
      } else {
        throw Exception('Failed to load comic details: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching comic details: $e');
      throw Exception('Failed to load comic details');
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method updates a comic with its full details from the database.
  /// It first checks the local cache, then fetches from the network if needed, and finally saves to the database.
  /// The method is essential for the caching and performance optimization functionality.
  Future<Comic> updateComicWithDetails(Comic comic) async {
    try {
      // Try to get from database first
      final cached = await DatabaseHelper.instance.getComic(comic.detailUrl);
      if (cached != null) {
        print('Using cached comic details for: ${comic.title}');
        return cached;
      }

      // If not in database, fetch from network
      final details = await fetchComicDetails(comic.detailUrl);
      final updated = Comic(
        title: comic.title,
        imageUrl: comic.imageUrl,
        detailUrl: comic.detailUrl,
        status: details['status'],
        author: details['author'],
        views: details['views'],
        genres: List<String>.from(details['genres'] ?? []),
        updateTime: details['updateTime'],
      );

      // Save to database
      final comicId = await DatabaseHelper.instance.insertComic(updated);
      print('Saved comic to database with id: $comicId');

      return updated;
    } catch (e) {
      print('Error updating comic details: $e');
      rethrow;
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
    print('❌ Error fetching image: $e');
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