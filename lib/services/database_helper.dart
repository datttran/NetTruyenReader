import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../models/comic.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'nettruyen_reader.db');

    print('🔍 DatabaseHelper: Initializing database at: $path');
    print('🔍 DatabaseHelper: Current database version: 8');
    
    return await openDatabase(
      path,
      version: 8, // Updated version for image data storage
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Comics table
    await db.execute('''
      CREATE TABLE comics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        detailUrl TEXT NOT NULL UNIQUE,
        status TEXT,
        author TEXT,
        views TEXT,
        updateTime TEXT,
        lastRead INTEGER,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Genres table
    await db.execute('''
      CREATE TABLE genres (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        url TEXT NOT NULL
      )
    ''');

    // Comic-Genre relationship table
    await db.execute('''
      CREATE TABLE comic_genres (
        comic_id INTEGER,
        genre_id INTEGER,
        FOREIGN KEY (comic_id) REFERENCES comics (id) ON DELETE CASCADE,
        FOREIGN KEY (genre_id) REFERENCES genres (id) ON DELETE CASCADE,
        PRIMARY KEY (comic_id, genre_id)
      )
    ''');

    // Chapters table
    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        comic_id INTEGER,
        url TEXT NOT NULL UNIQUE,
        number INTEGER NOT NULL,
        read INTEGER DEFAULT 0,
        cached_at INTEGER NOT NULL,
        FOREIGN KEY (comic_id) REFERENCES comics (id) ON DELETE CASCADE
      )
    ''');

    // Chapter images table for caching
    await db.execute('''
      CREATE TABLE chapter_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_url TEXT NOT NULL,
        image_url TEXT NOT NULL,
        image_order INTEGER NOT NULL,
        image_data BLOB NOT NULL,
        image_width INTEGER,
        image_height INTEGER,
        cached_at INTEGER NOT NULL,
        UNIQUE(chapter_url, image_order)
      )
    ''');

    // Chapter reading progress table (NEW - for chapter-specific scroll positions)
    await db.execute('''
      CREATE TABLE chapter_reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_url TEXT NOT NULL UNIQUE,
        current_page INTEGER DEFAULT 1,
        scroll_offset REAL DEFAULT 0.0,
        total_pages INTEGER DEFAULT 0,
        last_read_at INTEGER NOT NULL
      )
    ''');

    // Reading progress table
    await db.execute('''
      CREATE TABLE reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        comic_detail_url TEXT NOT NULL UNIQUE,
        last_chapter_url TEXT NOT NULL,
        last_chapter_number INTEGER,
        last_read_at INTEGER NOT NULL,
        completion_percentage REAL DEFAULT 0.0,
        current_page INTEGER DEFAULT 1,
        scroll_offset REAL DEFAULT 0.0,
        total_pages INTEGER DEFAULT 0,
        FOREIGN KEY (comic_detail_url) REFERENCES comics (detailUrl) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        // Check if url column already exists before adding it
        final columns = await db.rawQuery('PRAGMA table_info(genres)');
        final hasUrlColumn = columns.any((col) => col['name'] == 'url');

        if (!hasUrlColumn) {
          // Add URL column to genres table only if it doesn't exist
          await db.execute(
              'ALTER TABLE genres ADD COLUMN url TEXT NOT NULL DEFAULT ""');
        }

        // Update existing genres with empty URLs (they will be updated when comics are refreshed)
        await db.execute('UPDATE genres SET url = "" WHERE url IS NULL');
      } catch (e) {
        // Continue with the upgrade even if there's an error
      }
    }
    
    if (oldVersion < 3) {
      try {
        // Create reading progress table
        await db.execute('''
          CREATE TABLE reading_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            comic_detail_url TEXT NOT NULL UNIQUE,
            last_chapter_url TEXT NOT NULL,
            last_chapter_number INTEGER,
            last_read_at INTEGER NOT NULL,
            completion_percentage REAL DEFAULT 0.0,
            FOREIGN KEY (comic_detail_url) REFERENCES comics (detailUrl) ON DELETE CASCADE
          )
        ''');
        print('✅ Reading progress table created successfully');
      } catch (e) {
        print('❌ Error creating reading progress table: $e');
        // Continue with the upgrade even if there's an error
      }
    }
    
    if (oldVersion < 4) {
      try {
        // Update reading progress table to use completion_percentage
        await db.execute('''
          ALTER TABLE reading_progress 
          ADD COLUMN completion_percentage REAL DEFAULT 0.0
        ''');
        
        // Remove the old total_chapters_read column if it exists
        try {
          await db.execute('''
            ALTER TABLE reading_progress 
            DROP COLUMN total_chapters_read
          ''');
        } catch (e) {
          // Column might not exist, continue
        }
        
        print('✅ Reading progress table updated to use completion percentage');
      } catch (e) {
        print('❌ Error updating reading progress table: $e');
        // Continue with the upgrade even if there's an error
      }
    }
    
    if (oldVersion < 5) {
      try {
        // Add scroll tracking fields
        await db.execute('''
          ALTER TABLE reading_progress 
          ADD COLUMN current_page INTEGER DEFAULT 1
        ''');
        
        await db.execute('''
          ALTER TABLE reading_progress 
          ADD COLUMN scroll_offset REAL DEFAULT 0.0
        ''');
        
        await db.execute('''
          ALTER TABLE reading_progress 
          ADD COLUMN total_pages INTEGER DEFAULT 0
        ''');
        
        print('✅ Reading progress table updated with scroll tracking fields');
      } catch (e) {
        print('❌ Error updating reading progress table with scroll tracking: $e');
        // Continue with the upgrade even if there's an error
      }
    }
    
    if (oldVersion < 6) {
      try {
        // Create chapter images table for caching
        await db.execute('''
          CREATE TABLE chapter_images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter_url TEXT NOT NULL,
            image_url TEXT NOT NULL,
            image_order INTEGER NOT NULL,
            cached_at INTEGER NOT NULL,
            UNIQUE(chapter_url, image_order)
          )
        ''');
        
        print('✅ Chapter images table created successfully for caching');
      } catch (e) {
        print('❌ Error creating chapter images table: $e');
        // Continue with the upgrade even if there's an error
      }
    }
    
    if (oldVersion < 7) {
      try {
        print('🔍 DatabaseHelper: Upgrading from version $oldVersion to 7');
        print('🔍 DatabaseHelper: Creating chapter_reading_progress table...');
        
        // Create chapter reading progress table for chapter-specific scroll positions
        await db.execute('''
          CREATE TABLE chapter_reading_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter_url TEXT NOT NULL UNIQUE,
            current_page INTEGER DEFAULT 1,
            scroll_offset REAL DEFAULT 0.0,
            total_pages INTEGER DEFAULT 0,
            last_read_at INTEGER NOT NULL
          )
        ''');
        
        print('✅ Chapter reading progress table created successfully');
        print('🔍 DatabaseHelper: Database upgrade to version 7 completed');
      } catch (e) {
        print('❌ Error creating chapter reading progress table: $e');
        print('🔍 DatabaseHelper: Database upgrade to version 7 failed');
      }
    }
    
    if (oldVersion < 8) {
      try {
        print('🔍 DatabaseHelper: Upgrading from version $oldVersion to 8');
        print('🔍 DatabaseHelper: Recreating chapter_images table with new schema...');
        
        // Recreate the chapter_images table with new schema
        await _recreateChapterImagesTable(db);
        
        print('✅ Database upgrade to version 8 completed');
      } catch (e) {
        print('❌ Error upgrading to version 8: $e');
        print('🔍 DatabaseHelper: Database upgrade to version 8 failed');
      }
    }
  }

  // Force recreate chapter_images table with new schema (for version 8 upgrade)
  Future<void> _recreateChapterImagesTable(Database db) async {
    try {
      print('🔍 DatabaseHelper: Recreating chapter_images table with new schema...');
      
      // Drop the old table
      await db.execute('DROP TABLE IF EXISTS chapter_images');
      
      // Create new table with image data columns
      await db.execute('''
        CREATE TABLE chapter_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          chapter_url TEXT NOT NULL,
          image_url TEXT NOT NULL,
          image_order INTEGER NOT NULL,
          image_data BLOB NOT NULL,
          image_width INTEGER,
          image_height INTEGER,
          cached_at INTEGER NOT NULL,
          UNIQUE(chapter_url, image_order)
        )
      ''');
      
      print('✅ Chapter images table recreated with new schema');
    } catch (e) {
      print('❌ Error recreating chapter_images table: $e');
    }
  }

  // Comic operations
  Future<int> insertComic(Comic comic) async {
    final db = await database;

    // Insert or update comic
    final comicId = await db.insert(
      'comics',
      {
        'title': comic.title,
        'imageUrl': comic.imageUrl,
        'detailUrl': comic.detailUrl,
        'status': comic.status,
        'author': comic.author,
        'views': comic.views,
        'updateTime': comic.updateTime,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Insert genres
    for (final genre in comic.genres ?? <Genre>[]) {
      // First check if genre already exists
      final existingGenres = await db.query(
        'genres',
        where: 'name = ?',
        whereArgs: [genre.name],
      );

      int genreId;
      if (existingGenres.isNotEmpty) {
        // Use existing genre ID
        genreId = existingGenres.first['id'] as int;
      } else {
        // Insert new genre
        genreId = await db.insert(
          'genres',
          {
            'name': genre.name,
            'url': genre.url,
          },
        );
      }

      // Check if comic-genre relationship already exists
      final existingLinks = await db.query(
        'comic_genres',
        where: 'comic_id = ? AND genre_id = ?',
        whereArgs: [comicId, genreId],
      );

      if (existingLinks.isEmpty) {
        // Link comic and genre
        await db.insert(
          'comic_genres',
          {
            'comic_id': comicId,
            'genre_id': genreId,
          },
        );
      }
    }

    return comicId;
  }

  Future<Comic?> getComic(String detailUrl) async {
    final db = await database;

    final maps = await db.query(
      'comics',
      where: 'detailUrl = ?',
      whereArgs: [detailUrl],
    );

    if (maps.isEmpty) return null;

    // Get genres for this comic
    final genres = await db.rawQuery('''
      SELECT g.name, g.url FROM genres g
      INNER JOIN comic_genres cg ON g.id = cg.genre_id
      WHERE cg.comic_id = ?
    ''', [maps.first['id']]);

    return Comic(
      title: maps.first['title'] as String,
      imageUrl: maps.first['imageUrl'] as String,
      detailUrl: maps.first['detailUrl'] as String,
      status: maps.first['status'] as String?,
      author: maps.first['author'] as String?,
      views: maps.first['views'] as String?,
      genres: genres
          .map((g) => Genre(name: g['name'] as String, url: g['url'] as String))
          .toList(),
      updateTime: maps.first['updateTime'] as String?,
    );
  }

  /// Get the cache age (timestamp) for a comic
  Future<int?> getComicCacheAge(String detailUrl) async {
    final db = await database;

    final maps = await db.query(
      'comics',
      columns: ['cached_at'],
      where: 'detailUrl = ?',
      whereArgs: [detailUrl],
    );

    if (maps.isEmpty) return null;
    return maps.first['cached_at'] as int?;
  }

  /// Clear old cache entries (older than specified hours)
  Future<void> clearOldCache(int maxAgeHours) async {
    final db = await database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(hours: maxAgeHours))
        .millisecondsSinceEpoch;

    // Delete old comics
    await db.delete(
      'comics',
      where: 'cached_at < ?',
      whereArgs: [cutoffTime],
    );

    // Delete orphaned genres (no comics reference them)
    await db.rawDelete('''
      DELETE FROM genres 
      WHERE id NOT IN (
        SELECT DISTINCT genre_id FROM comic_genres
      )
    ''');
  }

  /// Clear all cache data (useful for debugging or resetting)
  Future<void> clearAllCache() async {
    final db = await database;

    print('🗑️ Clearing all cache data...');

    // Clear all tables
    await db.delete('comic_genres');
    await db.delete('genres');
    await db.delete('comics');
    await db.delete('chapters');

    print('🗑️ All cache data cleared');
  }

  /// Force database recreation (useful for fixing schema issues)
  Future<void> forceRecreateDatabase() async {
    final db = await database;

    print('🔄 Force recreating database...');

    // Close current database
    await db.close();

    // Delete database file
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'nettruyen_reader.db');
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      print('🗑️ Old database file deleted');
    }

    // Reopen database (this will trigger onCreate)
    await database;
    print('🔄 Database recreated successfully');
  }

  // Chapter operations
  Future<void> insertChapters(int comicId, List<String> chapterUrls) async {
    final db = await database;
    final batch = db.batch();

    for (var i = 0; i < chapterUrls.length; i++) {
      batch.insert(
        'chapters',
        {
          'comic_id': comicId,
          'url': chapterUrls[i],
          'number': i + 1,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  Future<List<String>> getChapters(int comicId) async {
    final db = await database;

    final chapters = await db.query(
      'chapters',
      where: 'comic_id = ?',
      whereArgs: [comicId],
      orderBy: 'number ASC',
    );

    return chapters.map((c) => c['url'] as String).toList();
  }

  // Cleanup old cache
  Future<void> cleanOldCache(Duration maxAge) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // Delete old comics and their related data (chapters and genre links will be deleted by CASCADE)
      await txn.delete(
        'comics',
        where: 'cached_at < ? AND lastRead IS NULL',
        whereArgs: [cutoff],
      );

      // Delete orphaned genres
      await txn.execute('''
        DELETE FROM genres 
        WHERE id NOT IN (SELECT DISTINCT genre_id FROM comic_genres)
      ''');
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('chapters');
      await txn.delete('comic_genres');
      await txn.delete('comics');
      await txn.delete('genres');
    });
  }

  Future<String> getDatabaseSize() async {
    try {
      final db = await database;
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'nettruyen_reader.db');

      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
      } else {
        return '0 MB';
      }
    } catch (e) {
      return 'Error calculating size';
    }
  }

  // Reading progress operations
  Future<void> saveReadingProgress({
    required String comicDetailUrl,
    required String chapterUrl,
    required int chapterNumber,
    required int lastAvailableChapter,
  }) async {
    final db = await database;
    
    try {
      // Calculate completion percentage
      // Formula: (last_read_chapter / last_available_chapter) × 100
      // This shows how much of the available content the user has completed
      final completionPercentage = (chapterNumber / lastAvailableChapter * 100).clamp(0.0, 100.0);
      
      // Check if a record already exists to preserve scroll progress
      final existingRecord = await db.query(
        'reading_progress',
        where: 'comic_detail_url = ?',
        whereArgs: [comicDetailUrl],
      );
      
      if (existingRecord.isNotEmpty) {
        // Update existing record while preserving scroll progress
        await db.execute('''
          UPDATE reading_progress 
          SET last_chapter_url = ?, last_chapter_number = ?, completion_percentage = ?, last_read_at = ?
          WHERE comic_detail_url = ?
        ''', [chapterUrl, chapterNumber, completionPercentage, DateTime.now().millisecondsSinceEpoch, comicDetailUrl]);
        
        print('✅ Reading progress updated for comic: $comicDetailUrl, chapter: $chapterNumber, completion: ${completionPercentage.toStringAsFixed(1)}% (${chapterNumber}/${lastAvailableChapter})');
      } else {
        // Insert new record with default values for scroll progress
        await db.insert(
          'reading_progress',
          {
            'comic_detail_url': comicDetailUrl,
            'last_chapter_url': chapterUrl,
            'last_chapter_number': chapterNumber,
            'last_read_at': DateTime.now().millisecondsSinceEpoch,
            'completion_percentage': completionPercentage,
            'current_page': 1, // Default to page 1
            'scroll_offset': 0.0, // Default to start
            'total_pages': 0, // Default to 0
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        print('✅ New reading progress record created for comic: $comicDetailUrl, chapter: $chapterNumber, completion: ${completionPercentage.toStringAsFixed(1)}% (${chapterNumber}/${lastAvailableChapter})');
      }
    } catch (e) {
      print('❌ Error saving reading progress: $e');
    }
  }

  // Save scroll progress (for page tracking and scroll position)
  Future<void> saveScrollProgress({
    required String comicDetailUrl,
    required int currentPage,
    required double scrollOffset,
    required int totalPages,
  }) async {
    final db = await database;
    
    try {
      // Check if a reading progress record already exists
      final existingRecord = await db.query(
        'reading_progress',
        where: 'comic_detail_url = ?',
        whereArgs: [comicDetailUrl],
      );
      
      if (existingRecord.isNotEmpty) {
        // Update existing record
        await db.execute('''
          UPDATE reading_progress 
          SET current_page = ?, scroll_offset = ?, total_pages = ?, last_read_at = ?
          WHERE comic_detail_url = ?
        ''', [currentPage, scrollOffset, totalPages, DateTime.now().millisecondsSinceEpoch, comicDetailUrl]);
        
        print('✅ Scroll progress updated for comic: $comicDetailUrl, page: $currentPage/$totalPages, offset: ${scrollOffset.toStringAsFixed(1)}');
      } else {
        // Insert new record with default values for missing fields
        await db.insert(
          'reading_progress',
          {
            'comic_detail_url': comicDetailUrl,
            'last_chapter_url': '', // Default empty string
            'last_chapter_number': 1, // Default to chapter 1
            'last_read_at': DateTime.now().millisecondsSinceEpoch,
            'completion_percentage': 0.0, // Default 0%
            'current_page': currentPage,
            'scroll_offset': scrollOffset,
            'total_pages': totalPages,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        print('✅ New scroll progress record created for comic: $comicDetailUrl, page: $currentPage/$totalPages, offset: ${scrollOffset.toStringAsFixed(1)}');
      }
    } catch (e) {
      print('❌ Error saving scroll progress: $e');
    }
  }

  // Save both reading and scroll progress in one call
  Future<void> saveCompleteProgress({
    required String comicDetailUrl,
    required String chapterUrl,
    required int chapterNumber,
    required int lastAvailableChapter,
    required int currentPage,
    required double scrollOffset,
    required int totalPages,
  }) async {
    final db = await database;
    
    try {
      // Calculate completion percentage
      final completionPercentage = (chapterNumber / lastAvailableChapter * 100).clamp(0.0, 100.0);
      
      await db.insert(
        'reading_progress',
        {
          'comic_detail_url': comicDetailUrl,
          'last_chapter_url': chapterUrl,
          'last_chapter_number': chapterNumber,
          'last_read_at': DateTime.now().millisecondsSinceEpoch,
          'completion_percentage': completionPercentage,
          'current_page': currentPage,
          'scroll_offset': scrollOffset,
          'total_pages': totalPages,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('✅ Complete progress saved for comic: $comicDetailUrl, chapter: $chapterNumber, page: $currentPage/$totalPages, completion: ${completionPercentage.toStringAsFixed(1)}%');
    } catch (e) {
      print('❌ Error saving complete progress: $e');
    }
  }

  Future<Map<String, dynamic>?> getReadingProgress(String comicDetailUrl) async {
    final db = await database;
    
    try {
      final result = await db.query(
        'reading_progress',
        where: 'comic_detail_url = ?',
        whereArgs: [comicDetailUrl],
      );
      
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      print('❌ Error getting reading progress: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllReadingProgress() async {
    final db = await database;
    
    try {
      final result = await db.query(
        'reading_progress',
        orderBy: 'last_read_at DESC',
      );
      
      return result;
    } catch (e) {
      print('❌ Error getting all reading progress: $e');
      return [];
    }
  }

  Future<void> clearReadingProgress(String comicDetailUrl) async {
    final db = await database;
    
    try {
      await db.delete(
        'reading_progress',
        where: 'comic_detail_url = ?',
        whereArgs: [comicDetailUrl],
      );
      print('✅ Reading progress cleared for comic: $comicDetailUrl');
    } catch (e) {
      print('❌ Error clearing reading progress: $e');
    }
  }

  // Chapter Images Caching Methods
  
  // Store chapter images with actual image data in database cache
  Future<void> cacheChapterImages(String chapterUrl, List<Map<String, dynamic>> imageData) async {
    final db = await database;
    
    try {
      // First, clear any existing cached images for this chapter
      await db.delete(
        'chapter_images',
        where: 'chapter_url = ?',
        whereArgs: [chapterUrl],
      );
      
      // Insert all images with their data
      for (int i = 0; i < imageData.length; i++) {
        final image = imageData[i];
        await db.insert(
          'chapter_images',
          {
            'chapter_url': chapterUrl,
            'image_url': image['url'] as String,
            'image_order': i,
            'image_data': image['data'] as List<int>,
            'image_width': image['width'] as int?,
            'image_height': image['height'] as int?,
            'cached_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      print('✅ Cached ${imageData.length} images with data for chapter: $chapterUrl');
    } catch (e) {
      print('❌ Error caching chapter images with data: $e');
    }
  }

  // Get cached chapter images with data from database
  Future<List<Map<String, dynamic>>> getCachedChapterImages(String chapterUrl) async {
    final db = await database;
    
    try {
      final result = await db.query(
        'chapter_images',
        where: 'chapter_url = ? AND image_data IS NOT NULL',
        whereArgs: [chapterUrl],
        orderBy: 'image_order ASC',
      );
      
      if (result.isNotEmpty) {
        final imageData = result.map((row) => {
          'url': row['image_url'] as String,
          'data': row['image_data'] as List<int>,
          'width': row['image_width'] as int?,
          'height': row['image_height'] as int?,
          'order': row['image_order'] as int,
        }).toList();
        
        print('✅ Retrieved ${imageData.length} cached images with data for chapter: $chapterUrl');
        return imageData;
      }
      
      print('📖 No cached images with data found for chapter: $chapterUrl');
      return [];
    } catch (e) {
      print('❌ Error getting cached chapter images with data: $e');
      return [];
    }
  }

  // Check if a chapter has cached images with data
  Future<bool> hasCachedChapterImages(String chapterUrl) async {
    final db = await database;
    
    try {
      final result = await db.query(
        'chapter_images',
        where: 'chapter_url = ? AND image_data IS NOT NULL',
        whereArgs: [chapterUrl],
        limit: 1,
      );
      
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error checking cached chapter images: $e');
      return false;
    }
  }

  // Clear cached images for a specific chapter
  Future<void> clearCachedChapterImages(String chapterUrl) async {
    final db = await database;
    
    try {
      final deletedCount = await db.delete(
        'chapter_images',
        where: 'chapter_url = ?',
        whereArgs: [chapterUrl],
      );
      
      print('✅ Cleared $deletedCount cached images for chapter: $chapterUrl');
    } catch (e) {
      print('❌ Error clearing cached chapter images: $e');
    }
  }

  // Clear all cached chapter images (for cleanup)
  Future<void> clearAllCachedChapterImages() async {
    final db = await database;
    
    try {
      final deletedCount = await db.delete('chapter_images');
      print('✅ Cleared all cached chapter images ($deletedCount images)');
    } catch (e) {
      print('❌ Error clearing all cached chapter images: $e');
    }
  }

  // Debug method to check database structure
  Future<void> debugDatabaseStructure() async {
    final db = await database;
    
    try {
      print('🔍 DatabaseHelper: Checking database structure...');
      
      // Check if chapter_reading_progress table exists
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      print('🔍 DatabaseHelper: Available tables: ${tables.map((t) => t['name']).toList()}');
      
      // Check chapter_reading_progress table structure
      try {
        final chapterProgressColumns = await db.rawQuery('PRAGMA table_info(chapter_reading_progress)');
        print('🔍 DatabaseHelper: chapter_reading_progress columns: ${chapterProgressColumns.map((c) => '${c['name']} (${c['type']})').toList()}');
      } catch (e) {
        print('❌ DatabaseHelper: chapter_reading_progress table not found or error: $e');
      }
      
      // Check reading_progress table structure
      try {
        final readingProgressColumns = await db.rawQuery('PRAGMA table_info(reading_progress)');
        print('🔍 DatabaseHelper: reading_progress columns: ${readingProgressColumns.map((c) => '${c['name']} (${c['type']})').toList()}');
      } catch (e) {
        print('❌ DatabaseHelper: reading_progress table not found or error: $e');
      }
      
    } catch (e) {
      print('❌ DatabaseHelper: Error checking database structure: $e');
    }
  }

  // Chapter Reading Progress Methods (NEW - for chapter-specific scroll positions)
  
  // Save chapter reading progress (scroll position, page, etc.)
  Future<void> saveChapterReadingProgress({
    required String chapterUrl,
    required int currentPage,
    required double scrollOffset,
    required int totalPages,
  }) async {
    final db = await database;
    
    try {
      print('🔍 DatabaseHelper: Saving chapter reading progress...');
      print('🔍 DatabaseHelper: Chapter URL: $chapterUrl');
      print('🔍 DatabaseHelper: Current Page: $currentPage');
      print('🔍 DatabaseHelper: Scroll Offset: ${scrollOffset.toStringAsFixed(1)}');
      print('🔍 DatabaseHelper: Total Pages: $totalPages');
      
      await db.insert(
        'chapter_reading_progress',
        {
          'chapter_url': chapterUrl,
          'current_page': currentPage,
          'scroll_offset': scrollOffset,
          'total_pages': totalPages,
          'last_read_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('✅ Chapter reading progress saved for: $chapterUrl, page: $currentPage/$totalPages, offset: ${scrollOffset.toStringAsFixed(1)}');
    } catch (e) {
      print('❌ Error saving chapter reading progress: $e');
      print('🔍 DatabaseHelper: Stack trace: ${StackTrace.current}');
    }
  }

  // Get chapter reading progress
  Future<Map<String, dynamic>?> getChapterReadingProgress(String chapterUrl) async {
    final db = await database;
    
    try {
      print('🔍 DatabaseHelper: Getting chapter reading progress for: $chapterUrl');
      
      final result = await db.query(
        'chapter_reading_progress',
        where: 'chapter_url = ?',
        whereArgs: [chapterUrl],
      );
      
      if (result.isNotEmpty) {
        print('✅ Retrieved chapter reading progress for: $chapterUrl');
        print('🔍 DatabaseHelper: Progress data: $result');
        return result.first;
      }
      
      print('📖 No chapter reading progress found for: $chapterUrl');
      return null;
    } catch (e) {
      print('❌ Error getting chapter reading progress: $e');
      print('🔍 DatabaseHelper: Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Check if chapter has reading progress
  Future<bool> hasChapterReadingProgress(String chapterUrl) async {
    final db = await database;
    
    try {
      final result = await db.query(
        'chapter_reading_progress',
        where: 'chapter_url = ?',
        whereArgs: [chapterUrl],
        limit: 1,
      );
      
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error checking chapter reading progress: $e');
      return false;
    }
  }

  // Clear chapter reading progress
  Future<void> clearChapterReadingProgress(String chapterUrl) async {
    final db = await database;
    
    try {
      final deletedCount = await db.delete(
        'chapter_reading_progress',
        where: 'chapter_url = ?',
        whereArgs: [chapterUrl],
      );
      
      print('✅ Cleared chapter reading progress for: $chapterUrl ($deletedCount records)');
    } catch (e) {
      print('❌ Error clearing chapter reading progress: $e');
    }
  }

  // Force database upgrade to latest version
  Future<void> forceDatabaseUpgrade() async {
    try {
      print('🔍 DatabaseHelper: Force upgrading database to version 8...');
      
      // Close existing database connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Delete the old database file to force recreation
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'nettruyen_reader.db');
      final file = File(path);
      
      if (await file.exists()) {
        await file.delete();
        print('🔍 DatabaseHelper: Old database file deleted, will recreate with new schema');
      }
      
      // Reinitialize database with new schema
      await database;
      print('✅ Database force upgrade completed successfully');
    } catch (e) {
      print('❌ Error during force database upgrade: $e');
    }
  }

  // Check if database needs upgrade
  Future<bool> needsUpgrade() async {
    try {
      final db = await database;
      final version = await db.getVersion();
      print('🔍 DatabaseHelper: Current database version: $version, Target: 8');
      return version < 8;
    } catch (e) {
      print('❌ Error checking database version: $e');
      return true; // Assume upgrade needed if we can't check
    }
  }
}
