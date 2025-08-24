// lib/constants/app_constants.dart

class AppConstants {
  static const String APP_NAME = 'Comic Reader';
  static const String APP_VERSION = '1.0.0';

  // Primary domain - DO NOT CHANGE: This is the fallback domain that ensures the app always works
  static const String PRIMARY_DOMAIN = 'https://nettruyenvia.com';

  // HTTP headers for Cloudflare bypass - DO NOT CHANGE: These headers successfully bypass Cloudflare protection
  static const Map<String, String> DEFAULT_HEADERS = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate',
    'Connection': 'keep-alive',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  // Network timeouts - DO NOT CHANGE: These timeouts are optimized for the current network conditions
  static const int CONNECTION_TIMEOUT = 30; // seconds
  static const int RETRY_DELAY = 2; // seconds
  static const int MAX_RETRIES = 3;

  // Cache settings - DO NOT CHANGE: These cache settings provide optimal performance
  static const String THUMB_CACHE_KEY = 'nettruyen_thumbnails';
  static const int CACHE_MAX_SIZE = 100 * 1024 * 1024; // 100MB
  static const int CACHE_MAX_OBJECTS = 200;

  // Pagination settings - DO NOT CHANGE: These pagination settings provide optimal UX
  static const int PAGE_SIZE = 12;
  static const double SCROLL_THRESHOLD = 0.8; // 80%
  static const int CACHE_EXTENT = 200; // pixels

  // Error messages
  static const String NETWORK_ERROR_MSG = 'Network error occurred';
  static const String PARSING_ERROR_MSG = 'Failed to parse content';
  static const String TIMEOUT_ERROR_MSG = 'Request timed out';
  static const String CLOUDFLARE_ERROR_MSG = 'Access blocked by Cloudflare';

  // Shared preferences keys
  static const String CUSTOM_DOMAIN_KEY = 'custom_domain';
  static const String USER_SETTINGS_KEY = 'user_settings';
  static const String LAST_UPDATE_KEY = 'last_update';

  // UI constants - Responsive design using percentage-based sizing
  static const double CARD_ELEVATION = 4.0;
  static const double CARD_BORDER_RADIUS = 8.0;
  static const double GRID_SPACING = 8.0;

  // Responsive card sizing - percentage of screen width
  static const double CARD_WIDTH_PERCENT =
      0.28; // 28% of screen width for reasonable reading size
  static const double CARD_HEIGHT_PERCENT =
      0.45; // 45% of screen height for proper aspect ratio
  static const double MIN_CARD_WIDTH = 120.0; // Minimum card width in pixels
  static const double MAX_CARD_WIDTH = 200.0; // Maximum card width in pixels

  // Responsive breakpoints for different screen sizes
  static const double MOBILE_BREAKPOINT = 600.0; // Mobile devices
  static const double TABLET_BREAKPOINT = 900.0; // Tablet devices
  static const double DESKTOP_BREAKPOINT = 1200.0; // Desktop devices

  // Card sizing for different breakpoints
  static const double MOBILE_CARD_WIDTH_PERCENT =
      0.42; // 42% for mobile (2 columns)
  static const double TABLET_CARD_WIDTH_PERCENT =
      0.28; // 28% for tablet (3-4 columns)
  static const double DESKTOP_CARD_WIDTH_PERCENT =
      0.22; // 22% for desktop (4-5 columns)

  // Card layout constants for proper image sizing
  static const double TEXT_SECTION_HEIGHT =
      60.0; // Fixed height for text section in pixels
  static const double CARD_PADDING =
      8.0; // Total padding (4px top + 4px bottom)
  static const double IMAGE_ASPECT_RATIO =
      0.65; // Standard comic thumbnail aspect ratio

  // Legacy constants (kept for backward compatibility)
  static const double THUMBNAIL_ASPECT_RATIO = 0.65;
  static const int GRID_CROSS_AXIS_COUNT = 3;

  // Animation durations
  static const Duration SHORT_ANIMATION = Duration(milliseconds: 200);
  static const Duration MEDIUM_ANIMATION = Duration(milliseconds: 300);
  static const Duration LONG_ANIMATION = Duration(milliseconds: 500);

  // Debug settings
  static const bool ENABLE_DEBUG_LOGGING = true;
  static const bool ENABLE_PERFORMANCE_LOGGING = false;
  static const bool ENABLE_NETWORK_LOGGING = true;

  // CRITICAL DISCOVERY: NetTruyen uses lazy loading with specific image attributes:
  // - 'src' = placeholder images (thumb-default.jpg) - DO NOT USE FIRST
  // - 'data-original' = real thumbnail URLs from CDN - USE FIRST
  // - 'data-retries' = backup thumbnail URLs - USE SECOND
  // - 'data-src' = alternative sources - USE THIRD
  //
  // Changing this priority order will break thumbnail display!
}
