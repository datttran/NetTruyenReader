// lib/utils/domain_helper.dart

import '../services/nettruyen_service.dart';

/// Shared utility class for domain management across all screens
/// Eliminates code duplication and provides consistent domain handling
class DomainHelper {
  /// Get the current domain from the service (fresh, no caching)
  /// Use this when you need the most up-to-date domain
  static Future<String> getCurrentDomain() async {
    return await NetTruyenService().getCurrentDomain();
  }
  
  /// Get cached domain with fallback to default
  /// Use this when you have a cached domain and want fast access
  static String getCachedDomain(String? cachedDomain) {
    return cachedDomain ?? 'https://nettruyen.com';
  }
  
  /// Get domain for HTTP headers with caching support
  /// This is the main method most screens should use
  static Future<String> getDomainForHeaders(String? cachedDomain) async {
    // If we have a cached domain, use it for immediate response
    if (cachedDomain != null) {
      return cachedDomain;
    }
    
    // Otherwise, get fresh domain from service
    return await getCurrentDomain();
  }
  
  /// Check if a domain has changed
  /// Useful for triggering content reloads
  static bool hasDomainChanged(String? oldDomain, String? newDomain) {
    if (oldDomain == null || newDomain == null) return false;
    return oldDomain != newDomain;
  }
}
