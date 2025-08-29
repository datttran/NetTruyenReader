import 'dart:typed_data';
import '../services/mangadex_service.dart';

/// Utility functions for MangaDex operations
class MangaDexUtils {
  /// Get high-quality MangaDex cover URL for a comic
  /// 
  /// Usage:
  /// ```dart
  /// final hdCoverUrl = await MangaDexUtils.getHdCoverUrl(comic.detailUrl);
  /// if (hdCoverUrl != null) {
  ///   // Use MangaDex cover
  ///   imageUrl = hdCoverUrl;
  /// } else {
  ///   // Use original thumbnail
  ///   imageUrl = comic.imageUrl;
  /// }
  /// ```
  /// 
  /// Returns:
  /// - `String?` - MangaDex cover URL if found and validated, null otherwise
  /// 
  /// Parameters:
  /// - `detailUrl` - The comic's detail URL (e.g., "https://nettruyenvia.com/truyen-tranh/vo-luyen-dinh-phong")
  static Future<String?> getHdCoverUrl(String detailUrl) async {
    return await MangaDexService.getMangaDexCoverUrl(detailUrl);
  }
  
  /// Download MangaDex image as bytes to avoid SSL issues
  /// 
  /// Usage:
  /// ```dart
  /// final imageBytes = await MangaDexUtils.downloadImage(mangaDexUrl);
  /// if (imageBytes != null) {
  ///   // Display using Image.memory(imageBytes)
  ///   return Image.memory(imageBytes);
  /// }
  /// ```
  /// 
  /// Returns:
  /// - `Uint8List?` - Image bytes if download successful, null otherwise
  /// 
  /// Parameters:
  /// - `url` - The MangaDex cover URL to download
  static Future<Uint8List?> downloadImage(String url) async {
    return await MangaDexService.downloadMangaDexImage(url);
  }
  
  /// Check if a URL is a MangaDex cover URL
  /// 
  /// Usage:
  /// ```dart
  /// if (MangaDexUtils.isMangaDexUrl(imageUrl)) {
  ///   // Handle MangaDex image display
  /// }
  /// ```
  /// 
  /// Returns:
  /// - `bool` - True if the URL is a MangaDex cover URL
  /// 
  /// Parameters:
  /// - `url` - The URL to check
  static bool isMangaDexUrl(String url) {
    return url.contains('uploads.mangadex.org/covers/');
  }
}
