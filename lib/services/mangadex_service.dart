import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data'; // Added for Uint8List
import 'mangadex_thumbnail_cache.dart';
import '../models/comic.dart';

/// Service for MangaDex API operations
class MangaDexService {
  static const String _baseUrl = 'https://api.mangadex.org';
  static const String _coversBaseUrl = 'https://uploads.mangadex.org/covers';
  
  /// Get high-quality MangaDex cover for a comic based on its Comic object
  /// This method can use alternative names for better matching
  /// Returns null if no suitable cover is found or validation fails
  static Future<String?> getMangaDexCoverUrlFromComic(Comic comic) async {
    try {
      // Extract manga name from NetTruyen URL
      // URL format: /truyen-tranh/vo-luyen-dinh-phong
      final uri = Uri.parse(comic.detailUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 2 && pathSegments[0] == 'truyen-tranh') {
        final mangaSlug = pathSegments[1]; // e.g., "vo-luyen-dinh-phong"
        
        // Convert slug to searchable format (replace hyphens with spaces)
        final searchTitle = mangaSlug.replaceAll('-', ' ');
        
        // Try multiple search strategies for better results
        String? mangaId;
        Map<String, dynamic>? mangaData;
        
        // Strategy 1: Search by title with higher limit
        final searchUrl1 = '$_baseUrl/manga?title=$searchTitle&limit=10&order[relevance]=desc';
        
        final searchResponse1 = await http.get(
          Uri.parse(searchUrl1),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (searchResponse1.statusCode == 200) {
          final searchData = json.decode(searchResponse1.body);
          final results = searchData['data'] as List?;
          
          if (results != null && results.isNotEmpty) {
            
            // Check each result for Vietnamese title match
            for (final manga in results) {
              final attributes = manga['attributes'] as Map<String, dynamic>?;
              if (attributes != null && attributes.containsKey('title')) {
                final title = attributes['title'] as Map<String, dynamic>?;
                final mangaDexVietnameseTitle = title?['vi'] as String?;
                final mangaDexEnglishTitle = title?['en'] as String?;
                final mangaDexJapaneseTitle = title?['ja'] as String?;
                
                // NEW: Check altTitles for Vietnamese title (this is where they're actually stored)
                String? mangaDexVietnameseAltTitle;
                if (attributes.containsKey('altTitles')) {
                  final altTitles = attributes['altTitles'] as List?;
                  if (altTitles != null) {
                    for (final altTitle in altTitles) {
                      if (altTitle is Map<String, dynamic> && altTitle.containsKey('vi')) {
                        mangaDexVietnameseAltTitle = altTitle['vi'] as String?;
                        break;
                      }
                    }
                  }
                }
                
                // Use altTitles Vietnamese title if available, fallback to main title
                final finalVietnameseTitle = mangaDexVietnameseAltTitle ?? mangaDexVietnameseTitle;
                
                bool shouldProceed = false;
                String matchReason = '';
                
                // Case 1: Check if Vietnamese title matches (more lenient)
                if (finalVietnameseTitle != null && finalVietnameseTitle.isNotEmpty) {
                  final originalLower = searchTitle.toLowerCase();
                  final mangaDexLower = finalVietnameseTitle.toLowerCase();
                  
                  // More lenient Vietnamese comparison - check for word overlap
                  final originalWords = originalLower.split(' ').where((word) => word.length > 1).toSet();
                  final mangaDexWords = mangaDexLower.split(' ').where((word) => word.length > 1).toSet();
                  
                  final commonWords = originalWords.intersection(mangaDexWords);
                  final totalWords = originalWords.union(mangaDexWords);
                  
                  if (totalWords.isNotEmpty) {
                    final similarity = commonWords.length / totalWords.length;
                    
                    if (similarity >= 0.5) { // At least 50% word overlap
                      shouldProceed = true;
                      matchReason = 'Vietnamese title word similarity: ${(similarity * 100).toStringAsFixed(1)}%';
                    }
                  }
                  
                  // Also check for substring containment as fallback
                  if (!shouldProceed && (mangaDexLower.contains(originalLower) || originalLower.contains(mangaDexLower))) {
                    shouldProceed = true;
                    matchReason = 'Vietnamese title substring match';
                  }
                }
                
                // Case 2: Check if English title matches (for English comics)
                if (!shouldProceed && mangaDexEnglishTitle != null && mangaDexEnglishTitle.isNotEmpty) {
                  final originalLower = searchTitle.toLowerCase();
                  final mangaDexLower = mangaDexEnglishTitle.toLowerCase();
                  
                  // Check for substring containment
                  if (mangaDexLower.contains(originalLower) || originalLower.contains(mangaDexLower)) {
                    shouldProceed = true;
                    matchReason = 'English title substring match';
                  }
                }
                
                // Case 3: Check if Japanese title matches (for Japanese comics)
                if (!shouldProceed && mangaDexJapaneseTitle != null && mangaDexJapaneseTitle.isNotEmpty) {
                  final originalLower = searchTitle.toLowerCase();
                  final mangaDexLower = mangaDexJapaneseTitle.toLowerCase();
                  
                  // Check for substring containment
                  if (mangaDexLower.contains(originalLower) || originalLower.contains(mangaDexLower)) {
                    shouldProceed = true;
                    matchReason = 'English title substring match';
                  }
                }
                
                if (shouldProceed) {
                  mangaId = manga['id'] as String?;
                  mangaData = manga;
                  break;
                }
              }
            }
          }
        }
        
        // Strategy 2: If no match found, try searching with alternative terms
        if (mangaId == null) {
          
          // Try searching with just the first few words
          final words = searchTitle.split(' ');
          if (words.length > 2) {
            final alternativeTitle = words.take(2).join(' '); // Take first 2 words
            
            final searchUrl2 = '$_baseUrl/manga?title=$alternativeTitle&limit=10&order[relevance]=desc';
            final searchResponse2 = await http.get(
              Uri.parse(searchUrl2),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'application/json',
              },
            ).timeout(const Duration(seconds: 10));
            
            if (searchResponse2.statusCode == 200) {
              final searchData = json.decode(searchResponse2.body);
              final results = searchData['data'] as List?;
              
              if (results != null && results.isNotEmpty) {
                
                // Check each result (same logic as above)
                for (final manga in results) {
                  final attributes = manga['attributes'] as Map<String, dynamic>?;
                  if (attributes != null && attributes.containsKey('title')) {
                    final title = attributes['title'] as Map<String, dynamic>?;
                    final mangaDexVietnameseTitle = title?['vi'] as String?;
                    
                    // Check altTitles for Vietnamese title
                    String? mangaDexVietnameseAltTitle;
                    if (attributes.containsKey('altTitles')) {
                      final altTitles = attributes['altTitles'] as List?;
                      if (altTitles != null) {
                        for (final altTitle in altTitles) {
                          if (altTitle is Map<String, dynamic> && altTitle.containsKey('vi')) {
                            mangaDexVietnameseAltTitle = altTitle['vi'] as String?;
                            break;
                          }
                        }
                      }
                    }
                    
                    final finalVietnameseTitle = mangaDexVietnameseAltTitle ?? mangaDexVietnameseTitle;
                    
                    if (finalVietnameseTitle != null && finalVietnameseTitle.isNotEmpty) {
                      final originalLower = alternativeTitle.toLowerCase();
                      final mangaDexLower = finalVietnameseTitle.toLowerCase();
                      
                      // Check for substring containment
                      if (mangaDexLower.contains(originalLower) || originalLower.contains(mangaDexLower)) {
                        mangaId = manga['id'] as String?;
                        mangaData = manga;
                        break;
                      }
                    }
                  }
                }
              }
            }
          }
        }
        
        // Strategy 3: Simple logic - check if any of our NetTruyen names match any of MangaDex alt names
        if (mangaId == null && comic.alternativeNames.isNotEmpty) {
          
          // Collect all our NetTruyen names (main title + alternative names)
          final allNetTruyenNames = <String>[
            searchTitle, // Main title from URL slug
            ...comic.alternativeNames,
          ];
          
          // Try each alternative name to search MangaDex
          for (final netTruyenName in allNetTruyenNames) {
            if (netTruyenName.trim().isEmpty) continue;
            
            final searchUrl3 = '$_baseUrl/manga?title=$netTruyenName&limit=5&order[relevance]=desc';
            final searchResponse3 = await http.get(
              Uri.parse(searchUrl3),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'application/json',
              },
            ).timeout(const Duration(seconds: 10));
            
            if (searchResponse3.statusCode == 200) {
              final searchData = json.decode(searchResponse3.body);
              final results = searchData['data'] as List?;
              
              if (results != null && results.isNotEmpty) {
                
                // Check each result: if ANY of our names match ANY of their alt names, use it
                for (final manga in results) {
                  final attributes = manga['attributes'] as Map<String, dynamic>?;
                  if (attributes != null) {
                    // Get all their alt names
                    final allMangaDexNames = <String>[];
                    
                    // Main titles
                    if (attributes.containsKey('title')) {
                      final title = attributes['title'] as Map<String, dynamic>?;
                      if (title != null) {
                        title.values.forEach((value) {
                          if (value is String && value.isNotEmpty) {
                            allMangaDexNames.add(value);
                          }
                        });
                      }
                    }
                    
                    // Alt titles
                    if (attributes.containsKey('altTitles')) {
                      final altTitles = attributes['altTitles'] as List?;
                      if (altTitles != null) {
                        for (final altTitle in altTitles) {
                          if (altTitle is Map<String, dynamic>) {
                            altTitle.values.forEach((value) {
                              if (value is String && value.isNotEmpty) {
                                allMangaDexNames.add(value);
                              }
                            });
                          }
                        }
                      }
                    }
                    
                    // Check if ANY of our names match ANY of their names
                    bool foundMatch = false;
                    String matchReason = '';
                    
                    for (final ourName in allNetTruyenNames) {
                      for (final theirName in allMangaDexNames) {
                        final ourLower = ourName.toLowerCase().trim();
                        final theirLower = theirName.toLowerCase().trim();
                        
                        // Simple contains check
                        if (ourLower.contains(theirLower) || theirLower.contains(ourLower)) {
                          foundMatch = true;
                          matchReason = '"$ourName" matches "$theirName"';
                          break;
                        }
                      }
                      if (foundMatch) break;
                    }
                    
                    if (foundMatch) {
                      mangaId = manga['id'] as String?;
                      mangaData = manga;
                      break;
                    }
                  }
                }
                
                if (mangaId != null) break; // Found a match, stop trying other names
              }
            }
          }
        }
        
        if (mangaId != null && mangaData != null) {
          
          // Now fetch covers using the dedicated cover art API
          final coverUrl = '$_baseUrl/cover?order[volume]=asc&manga[]=$mangaId&limit=100&offset=0';
          
          final coverResponse = await http.get(
            Uri.parse(coverUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 10));
          
          if (coverResponse.statusCode == 200) {
            final coverData = json.decode(coverResponse.body);
            final covers = coverData['data'] as List?;
            
            if (covers != null && covers.isNotEmpty) {
              // Get the first available cover (usually the main cover)
              final cover = covers.first;
              final coverId = cover['id'] as String?;
              final attributes = cover['attributes'] as Map<String, dynamic>?;
              final fileName = attributes?['fileName'] as String?;
              
              if (coverId != null && fileName != null) {
                // The fileName already contains the extension, so use it directly
                final coverUrl = '$_coversBaseUrl/$mangaId/$fileName';
                return coverUrl;
              }
            }
          }
        }
        
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Get high-quality MangaDex cover for a comic based on its thumbnail URL
  /// Returns null if no suitable cover is found or validation fails
  static Future<String?> getMangaDexCoverUrl(String thumbnailUrl) async {
    try {
      // Extract manga name from NetTruyen URL
      // URL format: /truyen-tranh/vo-luyen-dinh-phong
      final uri = Uri.parse(thumbnailUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 2 && pathSegments[0] == 'truyen-tranh') {
        final mangaSlug = pathSegments[1]; // e.g., "vo-luyen-dinh-phong"
        
        // Convert slug to searchable format (replace hyphens with spaces)
        final searchTitle = mangaSlug.replaceAll('-', ' ');
        
        // Try multiple search strategies for better results
        String? mangaId;
        Map<String, dynamic>? mangaData;
        
        // Strategy 1: Search by title with higher limit
        final searchUrl1 = '$_baseUrl/manga?title=$searchTitle&limit=10&order[relevance]=desc';
        
        final searchResponse1 = await http.get(
          Uri.parse(searchUrl1),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (searchResponse1.statusCode == 200) {
          final searchData = json.decode(searchResponse1.body);
          final results = searchData['data'] as List?;
          
          if (results != null && results.isNotEmpty) {
            
            // Check each result for Vietnamese title match
            for (final manga in results) {
              final attributes = manga['attributes'] as Map<String, dynamic>?;
              if (attributes != null && attributes.containsKey('title')) {
                final title = attributes['title'] as Map<String, dynamic>?;
                final mangaDexVietnameseTitle = title?['vi'] as String?;
                final mangaDexEnglishTitle = title?['en'] as String?;
                final mangaDexJapaneseTitle = title?['ja'] as String?;
                
                // NEW: Check altTitles for Vietnamese title (this is where they're actually stored)
                String? mangaDexVietnameseAltTitle;
                if (attributes.containsKey('altTitles')) {
                  final altTitles = attributes['altTitles'] as List?;
                  if (altTitles != null) {
                    for (final altTitle in altTitles) {
                      if (altTitle is Map<String, dynamic> && altTitle.containsKey('vi')) {
                        mangaDexVietnameseAltTitle = altTitle['vi'] as String?;
                        break;
                      }
                    }
                  }
                }
                
                // Use altTitles Vietnamese title if available, fallback to main title
                final finalVietnameseTitle = mangaDexVietnameseAltTitle ?? mangaDexVietnameseTitle;
                
                bool shouldProceed = false;
                String matchReason = '';
                
                // Case 1: Check if Vietnamese title matches (more lenient)
                if (finalVietnameseTitle != null && finalVietnameseTitle.isNotEmpty) {
                  final originalLower = searchTitle.toLowerCase();
                  final mangaDexLower = finalVietnameseTitle.toLowerCase();
                  
                  // More lenient Vietnamese comparison - check for word overlap
                  final originalWords = originalLower.split(' ').where((word) => word.length > 1).toSet();
                  final mangaDexWords = mangaDexLower.split(' ').where((word) => word.length > 1).toSet();
                  
                  final commonWords = originalWords.intersection(mangaDexWords);
                  final totalWords = originalWords.union(mangaDexWords);
                  
                  if (totalWords.isNotEmpty) {
                    final similarity = commonWords.length / totalWords.length;
                    
                    if (similarity >= 0.2) { // Lower threshold for Vietnamese (20% instead of 30%)
                      shouldProceed = true;
                      matchReason = 'Vietnamese title similarity: ${(similarity * 100).toStringAsFixed(1)}%';
                    }
                  }
                  
                  // Also check for substring containment
                  if (!shouldProceed) {
                    if (mangaDexLower.contains(originalLower) || originalLower.contains(mangaDexLower)) {
                      shouldProceed = true;
                      matchReason = 'Vietnamese title contains search term';
                    }
                  }
                } else {
                  // Case 4: Check Japanese title for similar patterns
                  if (!shouldProceed && mangaDexJapaneseTitle != null && mangaDexJapaneseTitle.isNotEmpty) {
                    final originalLower = searchTitle.toLowerCase();
                    final mangaDexJapaneseLower = mangaDexJapaneseTitle.toLowerCase();
                    
                    // Check for substring containment in Japanese
                    if (mangaDexJapaneseLower.contains(originalLower) || originalLower.contains(mangaDexJapaneseLower)) {
                      shouldProceed = true;
                      matchReason = 'Japanese title contains search term';
                    }
                  }
                }
                
                if (shouldProceed) {
                  mangaId = manga['id'] as String?;
                  mangaData = manga;
                  break; // Found a match, stop searching
                }
              }
            }
          }
        }
        
        // Strategy 2: If no match found, try searching with alternative terms
        if (mangaId == null) {
          
          // Try searching with just the first few words
          final words = searchTitle.split(' ');
          if (words.length > 2) {
            final alternativeTitle = words.take(2).join(' '); // Take first 2 words
            
            final searchUrl2 = '$_baseUrl/manga?title=$alternativeTitle&limit=10&order[relevance]=desc';
            final searchResponse2 = await http.get(
              Uri.parse(searchUrl2),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'application/json',
              },
            ).timeout(const Duration(seconds: 10));
            
            if (searchResponse2.statusCode == 200) {
              final searchData = json.decode(searchResponse2.body);
              final results = searchData['data'] as List?;
              
              if (results != null && results.isNotEmpty) {
                
                // Check each result (same logic as above)
                for (final manga in results) {
                  final attributes = manga['attributes'] as Map<String, dynamic>?;
                  if (attributes != null && attributes.containsKey('title')) {
                    final title = attributes['title'] as Map<String, dynamic>?;
                    final mangaDexVietnameseTitle = title?['vi'] as String?;
                    
                    // Check altTitles for Vietnamese title
                    String? mangaDexVietnameseAltTitle;
                    if (attributes.containsKey('altTitles')) {
                      final altTitles = attributes['altTitles'] as List?;
                      if (altTitles != null) {
                        for (final altTitle in altTitles) {
                          if (altTitle is Map<String, dynamic> && altTitle.containsKey('vi')) {
                            mangaDexVietnameseAltTitle = altTitle['vi'] as String?;
                            break;
                          }
                        }
                      }
                    }
                    
                    final finalVietnameseTitle = mangaDexVietnameseAltTitle ?? mangaDexVietnameseTitle;
                    
                    if (finalVietnameseTitle != null && finalVietnameseTitle.isNotEmpty) {
                      final originalLower = searchTitle.toLowerCase();
                      final mangaDexLower = finalVietnameseTitle.toLowerCase();
                      
                      // Check for substring containment
                      if (mangaDexLower.contains(originalLower) || originalLower.contains(mangaDexLower)) {
                        mangaId = manga['id'] as String?;
                        mangaData = manga;
                        break;
                      }
                    }
                  }
                }
              }
            }
          }
        }
        
        // Strategy 3: Alternative names support is available in getMangaDexCoverUrlFromComic method
        
        if (mangaId != null && mangaData != null) {
          
          // Now fetch covers using the dedicated cover art API
          final coverUrl = '$_baseUrl/cover?order[volume]=asc&manga[]=$mangaId&limit=100&offset=0';
          
          final coverResponse = await http.get(
            Uri.parse(coverUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 10));
          
          if (coverResponse.statusCode == 200) {
            final coverData = json.decode(coverResponse.body);
            final covers = coverData['data'] as List?;
            
            if (covers != null && covers.isNotEmpty) {
              // Get the first available cover (usually the main cover)
              final cover = covers.first;
              final coverId = cover['id'] as String?;
              final attributes = cover['attributes'] as Map<String, dynamic>?;
              final fileName = attributes?['fileName'] as String?;
              
              if (coverId != null && fileName != null) {
                // The fileName already contains the extension, so use it directly
                // Use uploads.mangadex.org to avoid SSL handshake issues
                final finalCoverUrl = '$_coversBaseUrl/$mangaId/$fileName';
                return finalCoverUrl;
              }
            } else {
              return null;
            }
          } else {
            return null;
          }
        } else {
          return null;
        }
        
        return null;
      } else {
        return null;
      }
      
    } catch (e, stackTrace) {
      return null;
    }
  }
  
  /// Check if a cached MangaDex thumbnail exists for the given comic URL
  /// Returns the cached image data if available, null otherwise
  static Future<Uint8List?> getCachedThumbnail(String comicUrl) async {
    return await MangaDexThumbnailCache.getCachedThumbnail(comicUrl);
  }
  
  /// Check if a valid cached thumbnail exists for the given comic URL
  static Future<bool> hasCachedThumbnail(String comicUrl) async {
    return await MangaDexThumbnailCache.hasValidCachedThumbnail(comicUrl);
  }
  
  /// Get the cached MangaDex URL for a comic (without loading the image)
  static Future<String?> getCachedMangaDexUrl(String comicUrl) async {
    return await MangaDexThumbnailCache.getCachedMangaDexUrl(comicUrl);
  }
  
  /// Pre-download MangaDex image to avoid SSL handshake issues
  /// Returns the image bytes if successful, null otherwise
  static Future<Uint8List?> downloadMangaDexImage(String url, {String? comicUrl}) async {
    try {
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        
        // Cache the downloaded image if comicUrl is provided
        if (comicUrl != null) {
          await MangaDexThumbnailCache.cacheThumbnail(comicUrl, url, response.bodyBytes);
        }
        
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  

}




