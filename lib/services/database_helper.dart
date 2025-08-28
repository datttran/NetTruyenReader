import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../models/comic.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nettruyen.db');

    return await openDatabase(
      path,
      version: 5, // Updated version for scroll tracking fields
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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nettruyen.db');
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
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'nettruyen.db');

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
      
      await db.insert(
        'reading_progress',
        {
          'comic_detail_url': comicDetailUrl,
          'last_chapter_url': chapterUrl,
          'last_chapter_number': chapterNumber,
          'last_read_at': DateTime.now().millisecondsSinceEpoch,
          'completion_percentage': completionPercentage,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('✅ Reading progress saved for comic: $comicDetailUrl, chapter: $chapterNumber, completion: ${completionPercentage.toStringAsFixed(1)}% (${chapterNumber}/${lastAvailableChapter})');
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
}
