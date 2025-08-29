# 🎯 MangaDex Integration Guide

This guide explains how to use the new MangaDex utility functions to enhance comic covers throughout the NetTruyen Reader app.

## 🚀 Quick Start

### Basic Usage

```dart
import '../utils/mangadex_utils.dart';

// Get HD cover URL for a comic
final hdCoverUrl = await MangaDexUtils.getHdCoverUrl(comic.detailUrl);

if (hdCoverUrl != null) {
  // Use MangaDex HD cover
  imageUrl = hdCoverUrl;
} else {
  // Fallback to original thumbnail
  imageUrl = comic.imageUrl;
}
```

## 📁 File Structure

```
lib/
├── services/
│   └── mangadex_service.dart          # Core MangaDex API service
├── utils/
│   └── mangadex_utils.dart            # Easy-to-use utility functions
└── examples/
    └── mangadex_usage_example.dart    # Usage examples for different scenarios
```

## 🔧 Core Functions

### 1. `MangaDexUtils.getHdCoverUrl(String detailUrl)`

**Purpose**: Gets a high-quality MangaDex cover URL for a comic.

**Parameters**:
- `detailUrl`: The comic's detail URL (e.g., "https://nettruyenvia.com/truyen-tranh/vo-luyen-dinh-phong")

**Returns**: 
- `String?` - MangaDex cover URL if found and validated, `null` otherwise

**Features**:
- ✅ **Vietnamese title validation** (30% similarity threshold)
- ✅ **English title validation** (50% similarity threshold + exact matches)
- ✅ **Smart title matching** for cases like "One Piece" (same in Vietnamese/English)
- ✅ **Automatic fallback** to original thumbnail
- ✅ **Comprehensive error handling** and logging

### 2. `MangaDexUtils.downloadImage(String url)`

**Purpose**: Downloads MangaDex images as bytes to avoid SSL handshake issues.

**Parameters**:
- `url`: The MangaDex cover URL to download

**Returns**:
- `Uint8List?` - Image bytes if download successful, `null` otherwise

**Use Case**: When you need to display MangaDex images using `Image.memory()` instead of `CachedNetworkImage`.

### 3. `MangaDexUtils.isMangaDexUrl(String url)`

**Purpose**: Checks if a URL is a MangaDex cover URL.

**Parameters**:
- `url`: The URL to check

**Returns**:
- `bool` - `true` if the URL is a MangaDex cover URL

## 🎨 Usage Examples

### Example 1: Enhanced Comic Card

```dart
Widget buildEnhancedComicCard(Comic comic) {
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
```

### Example 2: Detail Screen Header

```dart
Widget buildHdCoverHeader(Comic comic) {
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
```

### Example 3: Batch Processing

```dart
// Process multiple comics efficiently
Future<List<String?>> getBatchHdCovers(List<Comic> comics) async {
  final futures = comics.map((comic) => 
    MangaDexUtils.getHdCoverUrl(comic.detailUrl)
  ).toList();
  
  return await Future.wait(futures);
}

// Usage
final comics = await getComics();
final hdCovers = await getBatchHdCovers(comics);

// Process results
for (int i = 0; i < comics.length; i++) {
  final comic = comics[i];
  final hdCover = hdCovers[i];
  
  if (hdCover != null) {
    // Use HD cover
    print('${comic.title}: HD cover available');
  } else {
    // Use original
    print('${comic.title}: Using original thumbnail');
  }
}
```

## 🔒 Safety Features

### Smart Title Matching

The service uses a multi-layered approach to validate that MangaDex covers match the original comic:

#### **Case 1: Vietnamese Title Validation**
- Extracts Vietnamese title from MangaDex API response
- Compares with original title using word similarity
- **30% similarity threshold** for approval
- Filters out short words (< 3 characters) for accuracy

#### **Case 2: English Title Validation**
- Extracts English title from MangaDex API response
- **Exact match** for cases like "One Piece" (same in Vietnamese/English)
- **50% similarity threshold** for close matches
- Higher threshold ensures English accuracy

#### **Case 3: Substring Matching**
- Checks if search title is contained within English title
- Handles cases like "one piece" in "One Piece"
- Useful for partial matches and variations

#### **Validation Priority**
1. **Vietnamese title similarity** (30% threshold) - Primary method
2. **English title exact match** - For identical titles
3. **English title similarity** (50% threshold) - For close matches
4. **Substring containment** - For partial matches

### Vietnamese Title Validation

The service automatically validates that MangaDex covers match the original comic:

1. **Extracts Vietnamese title** from MangaDex API response
2. **Compares with original title** using word similarity
3. **30% similarity threshold** for approval
4. **Rejects if no Vietnamese title** on MangaDex
5. **Falls back to original** if validation fails

### Error Handling

- ✅ Network timeouts (10s for search, 15s for download)
- ✅ API errors (404, 500, etc.)
- ✅ Invalid responses
- ✅ Graceful fallbacks
- ✅ Comprehensive logging

## 📊 Performance Considerations

### Caching Strategy

- **MangaDex URLs are cached** by the service
- **Image downloads** can be cached using your existing cache manager
- **Batch processing** for multiple comics

### Network Optimization

- **Concurrent requests** for batch operations
- **Timeout handling** to prevent hanging requests
- **Fallback strategy** for failed requests

## 🐛 Debugging

### Enable Logging

The service provides detailed logging with the 🔍 emoji prefix:

#### **Example 1: Vietnamese Title Match**
```
🔍 MangaDex Service: Searching for "vo luyen dinh phong"
🔍 MangaDex Service: Found manga with ID: b1461071-bfbb-43e7-a5b6-a7ba5904649f
🔍 MangaDex Service: Title check:
   MangaDex Vietnamese: "Võ Luyện Đỉnh Phong"
   MangaDex English: "Martial Peak"
   Search Title: "vo luyen dinh phong"
🔍 MangaDex Service: Vietnamese similarity check:
   Original words: {vo, luyen, dinh, phong}
   MangaDex words: {võ, luyện, đỉnh, phong}
   Common words: {phong}
   Similarity score: 25.0%
🔍 MangaDex Service: ✅ Title match found: Vietnamese title similarity: 25.0%
```

#### **Example 2: English Title Exact Match**
```
🔍 MangaDex Service: Searching for "one piece"
🔍 MangaDex Service: Found manga with ID: a1c7c817-4e59-4b7a-9f53-1d4e7f1f8b9c
🔍 MangaDex Service: Title check:
   MangaDex Vietnamese: "One Piece"
   MangaDex English: "One Piece"
   Search Title: "one piece"
🔍 MangaDex Service: ✅ Title match found: Exact English title match
```

#### **Example 3: English Title Similarity**
```
🔍 MangaDex Service: Searching for "naruto"
🔍 MangaDex Service: Found manga with ID: b2d8d928-5f6a-5b8b-0g64-2e5f8g2g9c0d
🔍 MangaDex Service: Title check:
   MangaDex Vietnamese: "Naruto"
   MangaDex English: "Naruto"
   Search Title: "naruto"
🔍 MangaDex Service: ✅ Title match found: Exact English title match
```

### Common Issues

1. **No HD covers found**: Check if the comic has a Vietnamese title on MangaDex
2. **Low similarity scores**: Adjust the 30% threshold if needed
3. **Network timeouts**: Increase timeout values for slow connections
4. **SSL handshake errors**: Use `downloadImage()` method for problematic URLs

## 🔄 Migration Guide

### From Old Implementation

**Before**:
```dart
// Old method in detail_screen.dart
final mangaDexUrl = await _searchMangaDexForCover(comic.title, comic.detailUrl);
```

**After**:
```dart
// New utility function
import '../utils/mangadex_utils.dart';

final mangaDexUrl = await MangaDexUtils.getHdCoverUrl(comic.detailUrl);
```

### Benefits of Migration

- ✅ **Reusable** across the entire app
- ✅ **Consistent** behavior everywhere
- ✅ **Easier to maintain** and update
- ✅ **Better error handling** and logging
- ✅ **Performance optimizations**

## 🚀 Future Enhancements

### Planned Features

- [ ] **Batch validation** for multiple comics
- [ ] **Caching layer** for MangaDex search results
- [ ] **Priority queuing** for popular comics
- [ ] **Offline fallback** for cached covers
- [ ] **User preferences** for HD vs original

### Contributing

To add new features or improve the service:

1. **Update** `lib/services/mangadex_service.dart`
2. **Add utilities** to `lib/utils/mangadex_utils.dart`
3. **Create examples** in `lib/examples/mangadex_usage_example.dart`
4. **Update documentation** in this README

## 📞 Support

For questions or issues:

1. **Check the logs** for detailed error information
2. **Review examples** in the examples file
3. **Test with known comics** like "Võ Luyện Đỉnh Phong"
4. **Verify network connectivity** and API access

---

**Happy coding! 🎉**

The MangaDex integration is now available throughout your app, providing high-quality covers while maintaining safety and performance.

## 🎯 Use Cases

### **Vietnamese Comics** (Primary Use Case)
- **Võ Luyện Đỉnh Phong** → **Martial Peak** (Vietnamese title similarity)
- **Truyện Kiếm Hiệp** → **Wuxia Stories** (Vietnamese title similarity)

### **English Comics** (New Enhanced Support)
- **One Piece** → **One Piece** (Exact English match)
- **Naruto** → **Naruto** (Exact English match)
- **Dragon Ball** → **Dragon Ball** (Exact English match)

### **Mixed Language Comics**
- **Bleach** → **Bleach** (English title match)
- **Fairy Tail** → **Fairy Tail** (English title match)

### **Partial Matches**
- **one piece** → **One Piece** (Substring containment)
- **naruto** → **Naruto** (Case-insensitive match)
