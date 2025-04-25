import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/comic.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nettruyen.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
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
        name TEXT NOT NULL UNIQUE
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
    for (final genre in comic.genres ?? []) {
      final genreId = await db.insert(
        'genres',
        {'name': genre},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      
      // Link comic and genre
      await db.insert(
        'comic_genres',
        {
          'comic_id': comicId,
          'genre_id': genreId,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
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
      SELECT g.name FROM genres g
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
      genres: genres.map((g) => g['name'] as String).toList(),
      updateTime: maps.first['updateTime'] as String?,
    );
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
} 