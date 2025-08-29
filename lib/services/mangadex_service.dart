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
        
        print('🔍 MangaDex Service: Searching for "$searchTitle" with Comic object');
        print('🔍 MangaDex Service: Alternative names: ${comic.alternativeNames}');
        print('🔍 MangaDex Service: Alternative names count: ${comic.alternativeNames.length}');
        if (comic.alternativeNames.isNotEmpty) {
          for (int i = 0; i < comic.alternativeNames.length; i++) {
            print('🔍 MangaDex Service: Alternative name $i: "${comic.alternativeNames[i]}"');
          }
        }
        
        // Try multiple search strategies for better results
        String? mangaId;
        Map<String, dynamic>? mangaData;
        
        // Strategy 1: Search by title with higher limit
        final searchUrl1 = '$_baseUrl/manga?title=$searchTitle&limit=10&order[relevance]=desc';
        print('🔍 MangaDex Service: Strategy 1 - Title search: $searchUrl1');
        
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
            print('🔍 MangaDex Service: Found ${results.length} results in strategy 1');
            
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
                
                print('🔍 MangaDex Service: Title check:');
                print('   MangaDex Vietnamese (main): "${mangaDexVietnameseTitle ?? 'No Vietnamese title'}"');
                print('   MangaDex Vietnamese (alt): "${mangaDexVietnameseAltTitle ?? 'No Vietnamese alt title'}"');
                print('   MangaDex Vietnamese (final): "${finalVietnameseTitle ?? 'No Vietnamese title'}"');
                print('   MangaDex English: "${mangaDexEnglishTitle ?? 'No English title'}"');
                print('   MangaDex Japanese: "${mangaDexJapaneseTitle ?? 'No Japanese title'}"');
                print('   Search Title: "$searchTitle"');
                
                bool shouldProceed = false;
                String matchReason = '';
                
                // Case 1: Check if Vietnamese title matches (more lenient)
                if (finalVietnameseTitle != null && finalVietnameseTitle.isNotEmpty) {
                  final originalLower = searchTitle.toLowerCase();
                  final mangaDexLower = finalVietnameseTitle.toLowerCase();
                  
                  print('🔍 MangaDex Service: Vietnamese comparison details:');
                  print('   Original (lower): "$originalLower"');
                  print('   MangaDex (lower): "$mangaDexLower"');
                  
                  // More lenient Vietnamese comparison - check for word overlap
                  final originalWords = originalLower.split(' ').where((word) => word.length > 1).toSet();
                  final mangaDexWords = mangaDexLower.split(' ').where((word) => word.length > 1).toSet();
                  
                  final commonWords = originalWords.intersection(mangaDexWords);
                  final totalWords = originalWords.union(mangaDexWords);
                  
                  if (totalWords.isNotEmpty) {
                    final similarity = commonWords.length / totalWords.length;
                    print('🔍 MangaDex Service: Word similarity: ${commonWords.length}/${totalWords.length} = ${(similarity * 100).toStringAsFixed(1)}%');
                    
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
                  print('🔍 MangaDex Service: ✅ Match found: $matchReason');
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
          print('🔍 MangaDex Service: Strategy 1 failed, trying alternative search...');
          
          // Try searching with just the first few words
          final words = searchTitle.split(' ');
          if (words.length > 2) {
            final alternativeTitle = words.take(2).join(' '); // Take first 2 words
            print('🔍 MangaDex Service: Trying alternative title: "$alternativeTitle"');
            
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
                print('🔍 MangaDex Service: Found ${results.length} results in strategy 2');
                
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
                        print('🔍 MangaDex Service: ✅ Alternative title match found');
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
          print('🔍 MangaDex Service: Strategy 2 failed, trying simple alt name matching...');
          
          // Collect all our NetTruyen names (main title + alternative names)
          final allNetTruyenNames = <String>[
            searchTitle, // Main title from URL slug
            ...comic.alternativeNames,
          ];
          
          print('🔍 MangaDex Service: All NetTruyen names to check: $allNetTruyenNames');
          
          // Try each alternative name to search MangaDex
          for (final netTruyenName in allNetTruyenNames) {
            if (netTruyenName.trim().isEmpty) continue;
            
            print('🔍 MangaDex Service: Searching for: "$netTruyenName"');
            
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
                print('🔍 MangaDex Service: Found ${results.length} results for "$netTruyenName"');
                
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
                    
                    print('🔍 MangaDex Service: MangaDex names: $allMangaDexNames');
                    
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
                      print('🔍 MangaDex Service: ✅ Match found: $matchReason');
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
          print('🔍 MangaDex Service: Found manga with ID: $mangaId');
          
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
                print('🔍 MangaDex Service: ✅ Found cover URL: $coverUrl');
                return coverUrl;
              }
            }
          }
        }
        
        print('🔍 MangaDex Service: ❌ No suitable cover found');
        return null;
      } else {
        print('🔍 MangaDex Service: ❌ Invalid URL format: ${comic.detailUrl}');
        return null;
      }
    } catch (e) {
      print('🔍 MangaDex Service: ❌ Error getting MangaDex cover: $e');
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
        
        print('🔍 MangaDex Service: Searching for "$searchTitle"');
        
        // Try multiple search strategies for better results
        String? mangaId;
        Map<String, dynamic>? mangaData;
        
        // Strategy 1: Search by title with higher limit
        final searchUrl1 = '$_baseUrl/manga?title=$searchTitle&limit=10&order[relevance]=desc';
        print('🔍 MangaDex Service: Strategy 1 - Title search: $searchUrl1');
        
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
            print('🔍 MangaDex Service: Found ${results.length} results in strategy 1');
            
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
                
                print('🔍 MangaDex Service: Title check:');
                print('   MangaDex Vietnamese (main): "${mangaDexVietnameseTitle ?? 'No Vietnamese title'}"');
                print('   MangaDex Vietnamese (alt): "${mangaDexVietnameseAltTitle ?? 'No Vietnamese alt title'}"');
                print('   MangaDex Vietnamese (final): "${finalVietnameseTitle ?? 'No Vietnamese title'}"');
                print('   MangaDex English: "${mangaDexEnglishTitle ?? 'No English title'}"');
                print('   MangaDex Japanese: "${mangaDexJapaneseTitle ?? 'No Japanese title'}"');
                print('   Search Title: "$searchTitle"');
                
                bool shouldProceed = false;
                String matchReason = '';
                
                // Case 1: Check if Vietnamese title matches (more lenient)
                if (finalVietnameseTitle != null && finalVietnameseTitle.isNotEmpty) {
                  final originalLower = searchTitle.toLowerCase();
                  final mangaDexLower = finalVietnameseTitle.toLowerCase();
                  
                  print('🔍 MangaDex Service: Vietnamese comparison details:');
                  print('   Original (lower): "$originalLower"');
                  print('   MangaDex (lower): "$mangaDexLower"');
                  
                  // More lenient Vietnamese comparison - check for word overlap
                  final originalWords = originalLower.split(' ').where((word) => word.length > 1).toSet();
                  final mangaDexWords = mangaDexLower.split(' ').where((word) => word.length > 1).toSet();
                  
                  print('   Original words (>1 char): $originalWords');
                  print('   MangaDex words (>1 char): $mangaDexWords');
                  
                  final commonWords = originalWords.intersection(mangaDexWords);
                  final similarityScore = commonWords.length / originalWords.length;
                  
                  print('🔍 MangaDex Service: Vietnamese similarity check:');
                  print('   Original words: $originalWords');
                  print('   MangaDex words: $mangaDexWords');
                  print('   Common words: $commonWords');
                  print('   Similarity score: ${(similarityScore * 100).toStringAsFixed(1)}%');
                  print('   Threshold: 20%');
                  
                  // Lower threshold for Vietnamese (20% instead of 30%)
                  if (similarityScore >= 0.2) {
                    shouldProceed = true;
                    matchReason = 'Vietnamese title similarity: ${(similarityScore * 100).toStringAsFixed(1)}%';
                    print('🔍 MangaDex Service: ✅ Vietnamese similarity threshold met!');
                  } else {
                    print('🔍 MangaDex Service: ❌ Vietnamese similarity threshold not met');
                  }
                  
                  // Also check for substring containment
                  if (!shouldProceed) {
                    print('🔍 MangaDex Service: Checking substring containment...');
                    print('   Does "$mangaDexLower" contain "$originalLower"? ${mangaDexLower.contains(originalLower)}');
                    print('   Does "$originalLower" contain "$mangaDexLower"? ${originalLower.contains(mangaDexLower)}');
                    
                    if (mangaDexLower.contains(originalLower) || originalLower.contains(mangaDexLower)) {
                      shouldProceed = true;
                      matchReason = 'Vietnamese title contains search term';
                      print('🔍 MangaDex Service: ✅ Substring containment match found!');
                    } else {
                      print('🔍 MangaDex Service: ❌ No substring containment');
                    }
                  }
                } else {
                  print('🔍 MangaDex Service: ❌ No Vietnamese title available on MangaDex');
                }
                
                // Case 2: Check if English title matches exactly (for cases like "One Piece")
                if (!shouldProceed && mangaDexEnglishTitle != null && mangaDexEnglishTitle.isNotEmpty) {
                  final originalLower = searchTitle.toLowerCase();
                  final mangaDexEnglishLower = mangaDexEnglishTitle.toLowerCase();
                  
                  // Check for exact match or very close match
                  if (originalLower == mangaDexEnglishLower) {
                    shouldProceed = true;
                    matchReason = 'Exact English title match';
                  } else {
                    // Check for close similarity in English
                    final originalWords = originalLower.split(' ').where((word) => word.length > 2).toSet();
                    final mangaDexWords = mangaDexEnglishLower.split(' ').where((word) => word.length > 2).toSet();
                    
                    final commonWords = originalWords.intersection(mangaDexWords);
                    final similarityScore = commonWords.length / originalWords.length;
                    
                    print('🔍 MangaDex Service: English similarity check:');
                    print('   Original words: $originalWords');
                    print('   MangaDex English words: $mangaDexWords');
                    print('   Common words: $commonWords');
                    print('   Similarity score: ${(similarityScore * 100).toStringAsFixed(1)}%');
                    
                    if (similarityScore >= 0.5) { // Higher threshold for English
                      shouldProceed = true;
                      matchReason = 'English title similarity: ${(similarityScore * 100).toStringAsFixed(1)}%';
                    }
                  }
                }
                
                // Case 3: Check if search title is a subset of English title (e.g., "one piece" in "One Piece")
                if (!shouldProceed && mangaDexEnglishTitle != null && mangaDexEnglishTitle.isNotEmpty) {
                  final originalLower = searchTitle.toLowerCase();
                  final mangaDexEnglishLower = mangaDexEnglishTitle.toLowerCase();
                  
                  if (mangaDexEnglishLower.contains(originalLower) || originalLower.contains(mangaDexEnglishLower)) {
                    shouldProceed = true;
                    matchReason = 'Title contains search term';
                  }
                }
                
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
                
                if (shouldProceed) {
                  print('🔍 MangaDex Service: ✅ Title match found: $matchReason');
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
          print('🔍 MangaDex Service: Strategy 1 failed, trying alternative search...');
          
          // Try searching with just the first few words
          final words = searchTitle.split(' ');
          if (words.length > 2) {
            final alternativeTitle = words.take(2).join(' '); // Take first 2 words
            print('🔍 MangaDex Service: Trying alternative title: "$alternativeTitle"');
            
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
                print('🔍 MangaDex Service: Found ${results.length} results in strategy 2');
                
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
                        print('🔍 MangaDex Service: ✅ Alternative title match found');
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
          print('🔍 MangaDex Service: Found manga with ID: $mangaId');
          
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
                print('🔍 MangaDex Service: ✅ Found cover art: $finalCoverUrl');
                return finalCoverUrl;
              }
            } else {
              print('🔍 MangaDex Service: ❌ No covers found in response');
            }
          } else {
            print('🔍 MangaDex Service: ❌ Cover API Error: ${coverResponse.statusCode}');
          }
        } else {
          print('🔍 MangaDex Service: ❌ No suitable manga found after all strategies');
        }
        
        print('🔍 MangaDex Service: ❌ No MangaDex results found for: $searchTitle');
        return null;
      } else {
        print('🔍 MangaDex Service: ❌ Could not extract manga slug from URL: $thumbnailUrl');
        return null;
      }
      
    } catch (e, stackTrace) {
      print('🔍 MangaDex Service: ❌ Error searching MangaDex: $e');
      print('🔍 MangaDex Service: ❌ Stack Trace: $stackTrace');
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
      print('🔍 MangaDex Service: Starting download from $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        print('🔍 MangaDex Service: ✅ Download successful, size: ${response.bodyBytes.length} bytes');
        
        // Cache the downloaded image if comicUrl is provided
        if (comicUrl != null) {
          await MangaDexThumbnailCache.cacheThumbnail(comicUrl, url, response.bodyBytes);
        }
        
        return response.bodyBytes;
      } else {
        print('🔍 MangaDex Service: ❌ Download failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🔍 MangaDex Service: ❌ Download error: $e');
      return null;
    }
  }
  

}



