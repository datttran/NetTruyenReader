# Database Helper Documentation

## Overview
The `DatabaseHelper` manages local SQLite database operations for the NetTruyen Reader app. It handles comic caching, genre storage, and offline data persistence.

## Key Features

### 1. **Comic Caching**
- **Store comic data** locally for offline access
- **Cache thumbnails** and metadata
- **Reduce network requests** for better performance

### 2. **Genre Management**
- **Store genre information** with URLs
- **Support genre navigation** without network calls
- **Maintain genre relationships** with comics

### 3. **Database Migration**
- **Schema versioning** for app updates
- **Automatic migration** handling
- **Data preservation** during updates

## Database Schema

### 1. **Comics Table**
```sql
CREATE TABLE comics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  url TEXT NOT NULL UNIQUE,
  imageUrl TEXT NOT NULL,
  description TEXT,
  status TEXT,
  author TEXT,
  views TEXT,
  rating TEXT,
  lastUpdated TEXT,
  genres TEXT  -- JSON string of Genre objects
);
```

### 2. **Genres Table**
```sql
CREATE TABLE genres (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  comicId INTEGER NOT NULL,
  name TEXT NOT NULL,
  url TEXT NOT NULL,  -- Added in version 2
  FOREIGN KEY (comicId) REFERENCES comics (id)
);
```

### 3. **Chapters Table**
```sql
CREATE TABLE chapters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  comicId INTEGER NOT NULL,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  chapterNumber TEXT,
  lastUpdated TEXT,
  FOREIGN KEY (comicId) REFERENCES comics (id)
);
```

## Implementation Details

### 1. **Database Initialization**
```dart
class DatabaseHelper {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final path = await getDatabasesPath();
    final dbPath = join(path, 'nettruyen_reader.db');
    
    return await openDatabase(
      dbPath,
      version: 2,  // Current schema version
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }
}
```

### 2. **Table Creation**
```dart
Future<void> _createDB(Database db, int version) async {
  // Comics table
  await db.execute('''
    CREATE TABLE comics (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      url TEXT NOT NULL UNIQUE,
      imageUrl TEXT NOT NULL,
      description TEXT,
      status TEXT,
      author TEXT,
      views TEXT,
      rating TEXT,
      lastUpdated TEXT,
      genres TEXT
    )
  ''');
  
  // Genres table with URL support
  await db.execute('''
    CREATE TABLE genres (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      comicId INTEGER NOT NULL,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      FOREIGN KEY (comicId) REFERENCES comics (id)
    )
  ''');
  
  // Chapters table
  await db.execute('''
    CREATE TABLE chapters (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      comicId INTEGER NOT NULL,
      title TEXT NOT NULL,
      url TEXT NOT NULL,
      chapterNumber TEXT,
      lastUpdated TEXT,
      FOREIGN KEY (comicId) REFERENCES comics (id)
    )
  ''');
}
```

### 3. **Database Migration**
```dart
Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Add URL column to genres table
    await db.execute('ALTER TABLE genres ADD COLUMN url TEXT NOT NULL DEFAULT ""');
    
    print('🔍 Database upgraded from version $oldVersion to $newVersion');
    print('🔍 Added URL column to genres table');
  }
}
```

## Core Methods

### 1. **Comic Operations**

#### Insert Comic
```dart
Future<int> insertComic(Comic comic) async {
  final db = await database;
  
  // Convert genres to JSON string
  final genresJson = jsonEncode(
    comic.genres?.map((g) => g.toJson()).toList() ?? []
  );
  
  return await db.insert('comics', {
    'title': comic.title,
    'url': comic.url,
    'imageUrl': comic.imageUrl,
    'description': comic.description,
    'status': comic.status,
    'author': comic.author,
    'views': comic.views,
    'rating': comic.rating,
    'lastUpdated': comic.lastUpdated,
    'genres': genresJson,
  });
}
```

#### Get Comic
```dart
Future<Comic?> getComic(String url) async {
  final db = await database;
  
  final List<Map<String, dynamic>> maps = await db.query(
    'comics',
    where: 'url = ?',
    whereArgs: [url],
  );
  
  if (maps.isEmpty) return null;
  
  final map = maps.first;
  
  // Parse genres from JSON
  List<Genre> genres = [];
  if (map['genres'] != null) {
    final genresList = jsonDecode(map['genres']) as List;
    genres = genresList.map((g) => Genre.fromJson(g)).toList();
  }
  
  return Comic(
    title: map['title'],
    url: map['url'],
    imageUrl: map['imageUrl'],
    description: map['description'],
    status: map['status'],
    author: map['author'],
    views: map['views'],
    rating: map['rating'],
    lastUpdated: map['lastUpdated'],
    genres: genres,
  );
}
```

#### Update Comic
```dart
Future<int> updateComic(Comic comic) async {
  final db = await database;
  
  final genresJson = jsonEncode(
    comic.genres?.map((g) => g.toJson()).toList() ?? []
  );
  
  return await db.update(
    'comics',
    {
      'title': comic.title,
      'imageUrl': comic.imageUrl,
      'description': comic.description,
      'status': comic.status,
      'author': comic.author,
      'views': comic.views,
      'rating': comic.rating,
      'lastUpdated': comic.lastUpdated,
      'genres': genresJson,
    },
    where: 'url = ?',
    whereArgs: [comic.url],
  );
}
```

### 2. **Genre Operations**

#### Insert Genres
```dart
Future<void> insertGenres(int comicId, List<Genre> genres) async {
  final db = await database;
  
  final batch = db.batch();
  
  for (final genre in genres) {
    batch.insert('genres', {
      'comicId': comicId,
      'name': genre.name,
      'url': genre.url,  // ✅ Store genre URL for navigation
    });
  }
  
  await batch.commit();
}
```

#### Get Genres for Comic
```dart
Future<List<Genre>> getGenresForComic(int comicId) async {
  final db = await database;
  
  final List<Map<String, dynamic>> maps = await db.query(
    'genres',
    where: 'comicId = ?',
    whereArgs: [comicId],
  );
  
  return maps.map((map) => Genre(
    name: map['name'],
    url: map['url'],
  )).toList();
}
```

### 3. **Chapter Operations**

#### Insert Chapters
```dart
Future<void> insertChapters(int comicId, List<Chapter> chapters) async {
  final db = await database;
  
  final batch = db.batch();
  
  for (final chapter in chapters) {
    batch.insert('chapters', {
      'comicId': comicId,
      'title': chapter.title,
      'url': chapter.url,
      'chapterNumber': chapter.chapterNumber,
      'lastUpdated': chapter.lastUpdated,
    });
  }
  
  await batch.commit();
}
```

#### Get Chapters for Comic
```dart
Future<List<Chapter>> getChaptersForComic(int comicId) async {
  final db = await database;
  
  final List<Map<String, dynamic>> maps = await db.query(
    'chapters',
    where: 'comicId = ?',
    orderBy: 'chapterNumber ASC',
    whereArgs: [comicId],
  );
  
  return maps.map((map) => Chapter(
    title: map['title'],
    url: map['url'],
    chapterNumber: map['chapterNumber'],
    lastUpdated: map['lastUpdated'],
  )).toList();
}
```

## Data Models

### 1. **Genre Model**
```dart
class Genre {
  final String name;
  final String url;  // ✅ Added for navigation support
  
  Genre({
    required this.name,
    required this.url,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
  };
  
  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
    name: json['name'],
    url: json['url'],
  );
}
```

### 2. **Comic Model Integration**
```dart
class Comic {
  final String title;
  final String url;
  final String imageUrl;
  final String? description;
  final String? status;
  final String? author;
  final String? views;
  final String? rating;
  final String? lastUpdated;
  final List<Genre>? genres;  // ✅ List of Genre objects
  
  Comic({
    required this.title,
    required this.url,
    required this.imageUrl,
    this.description,
    this.status,
    this.author,
    this.views,
    this.rating,
    this.lastUpdated,
    this.genres,
  });
}
```

## Performance Optimizations

### 1. **Batch Operations**
```dart
// Use batch operations for multiple inserts
Future<void> insertMultipleComics(List<Comic> comics) async {
  final db = await database;
  final batch = db.batch();
  
  for (final comic in comics) {
    batch.insert('comics', comic.toMap());
  }
  
  await batch.commit();
}
```

### 2. **Indexing**
```dart
// Add indexes for frequently queried columns
await db.execute('CREATE INDEX idx_comics_url ON comics(url)');
await db.execute('CREATE INDEX idx_genres_comicId ON genres(comicId)');
await db.execute('CREATE INDEX idx_chapters_comicId ON chapters(comicId)');
```

### 3. **Query Optimization**
```dart
// Use specific columns instead of SELECT *
final List<Map<String, dynamic>> maps = await db.query(
  'comics',
  columns: ['title', 'url', 'imageUrl'],  // Only needed columns
  where: 'url = ?',
  whereArgs: [url],
);
```

## Error Handling

### 1. **Database Errors**
```dart
try {
  final result = await db.insert('comics', comicData);
  return result;
} catch (e) {
  if (e.toString().contains('UNIQUE constraint failed')) {
    print('⚠️ Comic already exists: ${comicData['url']}');
    return await updateComic(comicData);  // Update instead
  }
  print('❌ Database error: $e');
  rethrow;
}
```

### 2. **Migration Errors**
```dart
try {
  await _upgradeDB(db, oldVersion, newVersion);
} catch (e) {
  print('❌ Migration failed: $e');
  // Fallback: recreate database
  await db.close();
  await deleteDatabase(dbPath);
  return await _initDatabase();
}
```

### 3. **Data Validation**
```dart
Future<void> insertComic(Comic comic) async {
  // Validate required fields
  if (comic.title.isEmpty || comic.url.isEmpty || comic.imageUrl.isEmpty) {
    throw ArgumentError('Comic must have title, url, and imageUrl');
  }
  
  // Check for duplicate URLs
  final existing = await getComic(comic.url);
  if (existing != null) {
    print('⚠️ Comic already exists, updating: ${comic.url}');
    await updateComic(comic);
    return;
  }
  
  // Proceed with insert
  await _insertComicData(comic);
}
```

## Caching Strategy

### 1. **Cache Invalidation**
```dart
// Invalidate old cache entries
Future<void> cleanupOldCache() async {
  final db = await database;
  final cutoffDate = DateTime.now().subtract(Duration(days: 7));
  
  await db.delete(
    'comics',
    where: 'lastUpdated < ?',
    whereArgs: [cutoffDate.toIso8601String()],
  );
}
```

### 2. **Cache Size Management**
```dart
// Limit cache size to prevent database bloat
Future<void> limitCacheSize(int maxComics) async {
  final db = await database;
  
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM comics')
  ) ?? 0;
  
  if (count > maxComics) {
    final excess = count - maxComics;
    await db.rawDelete('''
      DELETE FROM comics 
      WHERE id IN (
        SELECT id FROM comics 
        ORDER BY lastUpdated ASC 
        LIMIT ?
      )
    ''', [excess]);
  }
}
```

### 3. **Smart Caching**
```dart
// Only cache frequently accessed comics
Future<void> cacheComicIfPopular(Comic comic) async {
  if (_isPopularComic(comic)) {
    await insertComic(comic);
  }
}

bool _isPopularComic(Comic comic) {
  // Cache logic based on views, rating, or recency
  return comic.views != null && int.tryParse(comic.views!) != null &&
         int.parse(comic.views!) > 1000;
}
```

## Testing and Debugging

### 1. **Database Inspection**
```dart
// Debug method to inspect database contents
Future<void> debugDatabase() async {
  final db = await database;
  
  final comics = await db.query('comics');
  final genres = await db.query('genres');
  final chapters = await db.query('chapters');
  
  print('🔍 Database contents:');
  print('📚 Comics: ${comics.length}');
  print('🏷️ Genres: ${genres.length}');
  print('📖 Chapters: ${chapters.length}');
  
  // Show sample data
  if (comics.isNotEmpty) {
    print('🔍 Sample comic: ${comics.first}');
  }
}
```

### 2. **Performance Monitoring**
```dart
// Monitor query performance
Future<void> measureQueryPerformance() async {
  final stopwatch = Stopwatch()..start();
  
  final comics = await getAllComics();
  
  stopwatch.stop();
  print('🔍 Query took: ${stopwatch.elapsedMilliseconds}ms');
  print('🔍 Retrieved: ${comics.length} comics');
}
```

## Future Enhancements

### 1. **Advanced Caching**
- **TTL-based expiration** for cache entries
- **LRU eviction** for memory management
- **Background cache warming** for popular content

### 2. **Data Synchronization**
- **Conflict resolution** for offline changes
- **Incremental updates** to reduce bandwidth
- **Multi-device sync** support

### 3. **Performance Monitoring**
- **Query analytics** for optimization
- **Cache hit rates** tracking
- **Database size** monitoring

---

## Summary

The `DatabaseHelper` provides robust local data persistence with:

1. **Efficient caching** for offline access
2. **Proper schema management** with migrations
3. **Genre navigation support** with URL storage
4. **Performance optimizations** for large datasets
5. **Comprehensive error handling** for reliability

This component is essential for the app's offline functionality and performance optimization.

---

*Last updated: [Current Date]*
*Database Version: 2.0*
*Status: ✅ Production Ready* 