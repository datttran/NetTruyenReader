# Caching Testing Guide

## Overview
This guide explains how to test and verify that the genre caching system is working correctly in the NetTruyen Reader app.

## 🚀 How to Test Caching

### **1. Check Console Logs**
The app now provides detailed logging for all cache operations. Look for these emojis in the console:

- **🚀** - Cache HIT (using cached data - instant loading)
- **🌐** - Cache MISS (fetching new data - slower loading)
- **📊** - Cache status reports
- **🔍** - General operations
- **🧹** - Cache clearing operations

### **2. Test Cache Status Button**
- **Tap the info icon** (ℹ️) in the app bar to log current cache status
- **Long press the info icon** to clear all cache entries

### **3. Step-by-Step Testing Process**

#### **Step 1: Initial Load**
1. Start the app
2. Check console for initial cache status (should be empty)
3. Verify "Phổ biến" tab loads comics from main domain (should show CACHE MISS initially)

#### **Step 2: First Genre Selection**
1. Tap any genre tab (e.g., "Action")
2. Check console for:
   ```
   🌐 CACHE MISS! Fetching comics by genre: Action
   🌐 Loaded X comics for genre: Action
   🔍 Cached X comics for genre: /tim-truyen/action-95
   📊 === CACHE STATUS ===
   📊 Total cached genres: 1
   📊 Genre: /tim-truyen/action-95
   📊   Comics: X
   📊   Age: 0m 5s
   📊   Valid: ✅
   📊 ====================
   ```

#### **Step 3: Switch to Another Genre**
1. Tap a different genre (e.g., "Comedy")
2. Check console for another CACHE MISS and caching

#### **Step 4: Return to Previous Genre**
1. Tap back to "Action" genre
2. Check console for:
   ```
   🚀 CACHE HIT! Using cached data for genre: Action
   🚀 Cache age: 15s
   ```
3. **No network request should be made** - data loads instantly from cache

#### **Step 5: Test Popular Comics Caching**
1. Switch back to "Phổ biến" tab
2. Should see `🚀 CACHE HIT! Using cached popular comics` (instant loading)
3. If it's the first time, should see `🌐 CACHE MISS! Loading popular comics from main domain...`

#### **Step 6: Check Cache Status**
1. Tap the info icon (ℹ️) in app bar
2. Verify cache contains both popular comics and genres with their ages

### **4. Cache Expiration Testing**

#### **Test 1: Wait for Expiration**
1. Load several genres to cache them
2. Wait 10+ minutes (cache expiry time)
3. Switch back to a cached genre
4. Should see CACHE MISS instead of CACHE HIT

#### **Test 2: Manual Cache Clear**
1. Long press the info icon (ℹ️) to clear all cache
2. Switch to any genre - should see CACHE MISS
3. Check console for cache clearing confirmation

### **5. Performance Testing**

#### **Cache Hit Performance**
- **With cache**: Genre switching should be **instant** (0-50ms)
- **Without cache**: Genre switching should take **1-3 seconds** (network request)

#### **Memory Usage**
- Check console for cache entry counts
- Each genre typically caches 20-50 comics
- Cache size should remain reasonable

## 🔍 What to Look For

### **✅ Caching Working Correctly:**
- CACHE HIT messages when switching back to previously loaded genres
- Instant loading for cached genres
- Cache status shows multiple genres with timestamps
- No duplicate network requests for same genre

### **❌ Caching Not Working:**
- Always seeing CACHE MISS messages
- Slow loading even for previously visited genres
- Cache status shows 0 or 1 genres
- Network requests repeated for same genre

### **⚠️ Potential Issues:**
- Cache not persisting between app restarts
- Memory leaks (cache growing indefinitely)
- Cache expiry not working (old data never cleared)

## 🛠️ Debugging Commands

### **Check Current Cache:**
```dart
// Tap info icon in app bar
// Console will show detailed cache status
```

### **Clear All Cache:**
```dart
// Long press info icon in app bar
// Console will confirm cache cleared
```

### **Force Cache Expiry:**
```dart
// Wait 10+ minutes
// Or modify _cacheExpiry constant to shorter duration for testing
```

## 📊 Expected Console Output

### **First Time Loading Genre:**
```
🌐 CACHE MISS! Fetching comics by genre: Action
🌐 Loaded 25 comics for genre: Action
🔍 Cached 25 comics for genre: /tim-truyen/action-95
📊 === CACHE STATUS ===
📊 Total cached genres: 1
📊 Genre: /tim-truyen/action-95
📊   Comics: 25
📊   Age: 0m 3s
📊   Valid: ✅
📊 ====================
```

### **Returning to Cached Genre:**
```
🚀 CACHE HIT! Using cached data for genre: Action
🚀 Cache age: 45s
```

### **Cache Status Report:**
```
📊 === CACHE STATUS ===
📊 Total cached items: 4
📊 Popular Comics:
📊   Comics: 36
📊   Age: 1m 45s
📊   Valid: ✅

📊 Genre: /tim-truyen/action-95
📊   Comics: 25
📊   Age: 2m 15s
📊   Valid: ✅
📊 Genre: /tim-truyen/comedy-99
📊   Comics: 18
📊   Age: 1m 30s
📊   Valid: ✅
📊 Genre: /tim-truyen/romance-121
📊   Comics: 22
📊   Age: 0m 45s
📊   Valid: ✅
📊 ====================
```

## 🎯 Success Criteria

The caching system is working correctly if:

1. **First visit to genre**: Shows CACHE MISS and loads from network
2. **Return visit to genre**: Shows CACHE HIT and loads instantly
3. **Cache status**: Shows multiple genres with proper timestamps
4. **Performance**: Cached genres load 10x+ faster than uncached
5. **Memory management**: Cache doesn't grow indefinitely
6. **Expiration**: Old cache entries are automatically cleaned up

## 🚨 Troubleshooting

### **Cache Not Working:**
- Check if `_genreCache` and `_genreCacheTimestamps` are properly initialized
- Verify `_isGenreCacheValid()` logic
- Check for exceptions in cache operations

### **Performance Issues:**
- Monitor cache size growth
- Check if cache expiry is working
- Verify deduplication is applied to cached data

### **Memory Issues:**
- Implement cache size limits if needed
- Add periodic cache cleanup
- Monitor memory usage in debug console 