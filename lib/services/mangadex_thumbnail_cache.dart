import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service for caching MangaDex thumbnails to avoid repeated API calls
class MangaDexThumbnailCache {
  static const String _cacheKey = 'mangadex_thumbnail_cache';
  static const String _cacheDir = 'mangadex_thumbnails';
  static const int _maxCacheSize = 100; // Maximum number of cached thumbnails
  static const int _maxFileAge = 30; // Maximum age in days for cached files
  
  /// Cache a MangaDex thumbnail for a given comic URL
  static Future<void> cacheThumbnail(String comicUrl, String mangadexUrl, Uint8List imageData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey) ?? '{}';
      final cache = Map<String, dynamic>.from(json.decode(cacheData));
      
      // Create cache entry
      final cacheEntry = {
        'mangadexUrl': mangadexUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'size': imageData.length,
      };
      
      // Store image file
      final fileName = await _storeImageFile(comicUrl, imageData);
      if (fileName != null) {
        cacheEntry['fileName'] = fileName;
        
        // Add to cache
        cache[comicUrl] = cacheEntry;
        
        // Clean up old entries if cache is too large
        await _cleanupCache(cache);
        
        // Save updated cache
        await prefs.setString(_cacheKey, json.encode(cache));
        
        print('🔍 MangaDex Cache: ✅ Cached thumbnail for $comicUrl');
      }
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error caching thumbnail: $e');
    }
  }
  
  /// Retrieve a cached MangaDex thumbnail for a given comic URL
  static Future<Uint8List?> getCachedThumbnail(String comicUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey) ?? '{}';
      final cache = Map<String, dynamic>.from(json.decode(cacheData));
      
      if (cache.containsKey(comicUrl)) {
        final entry = cache[comicUrl] as Map<String, dynamic>;
        final fileName = entry['fileName'] as String?;
        final timestamp = entry['timestamp'] as int?;
        
        if (fileName != null && timestamp != null) {
          // Check if file is still valid (not too old)
          final fileAge = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
          if (fileAge.inDays < _maxFileAge) {
            // Try to load the cached image
            final imageData = await _loadImageFile(fileName);
            if (imageData != null) {
              print('🔍 MangaDex Cache: ✅ Retrieved cached thumbnail for $comicUrl');
              return imageData;
            }
          } else {
            // File is too old, remove from cache
            await _removeCachedThumbnail(comicUrl);
            print('🔍 MangaDex Cache: 🗑️ Removed expired thumbnail for $comicUrl');
          }
        }
      }
      
      print('🔍 MangaDex Cache: ❌ No cached thumbnail found for $comicUrl');
      return null;
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error retrieving cached thumbnail: $e');
      return null;
    }
  }
  
  /// Check if a cached thumbnail exists and is valid
  static Future<bool> hasValidCachedThumbnail(String comicUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey) ?? '{}';
      final cache = Map<String, dynamic>.from(json.decode(cacheData));
      
      if (cache.containsKey(comicUrl)) {
        final entry = cache[comicUrl] as Map<String, dynamic>;
        final fileName = entry['fileName'] as String?;
        final timestamp = entry['timestamp'] as int?;
        
        if (fileName != null && timestamp != null) {
          // Check if file is still valid
          final fileAge = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
          if (fileAge.inDays < _maxFileAge) {
            // Check if file actually exists
            final file = await _getImageFile(fileName);
            return await file.exists();
          }
        }
      }
      
      return false;
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error checking cached thumbnail: $e');
      return false;
    }
  }
  
  /// Get the cached MangaDex URL for a comic (without loading the image)
  static Future<String?> getCachedMangaDexUrl(String comicUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey) ?? '{}';
      final cache = Map<String, dynamic>.from(json.decode(cacheData));
      
      if (cache.containsKey(comicUrl)) {
        final entry = cache[comicUrl] as Map<String, dynamic>;
        final timestamp = entry['timestamp'] as int?;
        
        if (timestamp != null) {
          // Check if entry is still valid
          final fileAge = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
          if (fileAge.inDays < _maxFileAge) {
            return entry['mangadexUrl'] as String?;
          }
        }
      }
      
      return null;
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error getting cached MangaDex URL: $e');
      return null;
    }
  }
  
  /// Remove a specific cached thumbnail
  static Future<void> _removeCachedThumbnail(String comicUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey) ?? '{}';
      final cache = Map<String, dynamic>.from(json.decode(cacheData));
      
      if (cache.containsKey(comicUrl)) {
        final entry = cache[comicUrl] as Map<String, dynamic>;
        final fileName = entry['fileName'] as String?;
        
        // Remove image file
        if (fileName != null) {
          await _deleteImageFile(fileName);
        }
        
        // Remove from cache
        cache.remove(comicUrl);
        await prefs.setString(_cacheKey, json.encode(cache));
      }
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error removing cached thumbnail: $e');
    }
  }
  
  /// Clean up old cache entries
  static Future<void> _cleanupCache(Map<String, dynamic> cache) async {
    if (cache.length <= _maxCacheSize) return;
    
    try {
      // Sort by timestamp (oldest first)
      final sortedEntries = cache.entries.toList()
        ..sort((a, b) => (a.value['timestamp'] as int).compareTo(b.value['timestamp'] as int));
      
      // Remove oldest entries until we're under the limit
      final entriesToRemove = sortedEntries.take(cache.length - _maxCacheSize);
      
      for (final entry in entriesToRemove) {
        final fileName = entry.value['fileName'] as String?;
        if (fileName != null) {
          await _deleteImageFile(fileName);
        }
        cache.remove(entry.key);
      }
      
      print('🔍 MangaDex Cache: 🗑️ Cleaned up ${entriesToRemove.length} old entries');
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error cleaning up cache: $e');
    }
  }
  
  /// Store image file and return filename
  static Future<String?> _storeImageFile(String comicUrl, Uint8List imageData) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _generateFileName(comicUrl);
      final file = File('${cacheDir.path}/$fileName');
      
      await file.writeAsBytes(imageData);
      return fileName;
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error storing image file: $e');
      return null;
    }
  }
  
  /// Load image file and return image data
  static Future<Uint8List?> _loadImageFile(String fileName) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error loading image file: $e');
      return null;
    }
  }
  
  /// Get image file reference
  static Future<File> _getImageFile(String fileName) async {
    final cacheDir = await _getCacheDirectory();
    return File('${cacheDir.path}/$fileName');
  }
  
  /// Delete image file
  static Future<void> _deleteImageFile(String fileName) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error deleting image file: $e');
    }
  }
  
  /// Get or create cache directory
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }
  
  /// Generate filename for cached image
  static String _generateFileName(String comicUrl) {
    // Create a hash from the comic URL to use as filename
    final hash = comicUrl.hashCode.abs();
    return 'mangadex_$hash.jpg';
  }
  
  /// Clear all cached thumbnails
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      
      print('🔍 MangaDex Cache: 🗑️ Cleared all cached thumbnails');
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error clearing cache: $e');
    }
  }
  
  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey) ?? '{}';
      final cache = Map<String, dynamic>.from(json.decode(cacheData));
      
      final cacheDir = await _getCacheDirectory();
      int totalSize = 0;
      
      if (await cacheDir.exists()) {
        final files = cacheDir.listSync();
        for (final file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
      
      return {
        'entryCount': cache.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'maxEntries': _maxCacheSize,
        'maxAgeDays': _maxFileAge,
      };
    } catch (e) {
      print('🔍 MangaDex Cache: ❌ Error getting cache stats: $e');
      return {};
    }
  }
}
