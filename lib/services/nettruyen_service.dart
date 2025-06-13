import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comic.dart';
import '../screens/cloudflare_bypass_screen.dart';

import 'package:http/http.dart' as http;


import 'package:html/parser.dart';

import '../services/database_helper.dart';


Future<http.Response> getWithSavedCookies(String url) async {
  final prefs = await SharedPreferences.getInstance();
  final savedCookie = prefs.getString('cookie');

  final headers = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Mobile Safari/537.36',
    // Use your real user agent if you have one set
  };

  if (savedCookie != null) {
    headers['Cookie'] = savedCookie;
  }

  return await http.get(Uri.parse(url), headers: headers);
}




 const _base = 'https://nettruyenvio.com';


/// Thrown when Cloudflare returns a 403 on our search URL.
class CloudflareException implements Exception {
  final String url;
  CloudflareException(this.url);
}

/// Represents a single page with its chapter information
class PageItem {
  final String imageUrl;
  final int chapterIndex;

  PageItem({required this.imageUrl, required this.chapterIndex});
}

class NetTruyenService {

  /// Fetch comics by loading JS-rendered page in a headless WebView
  final _client = http.Client();
  static const _baseHeaders = {
    'User-Agent': 'Mozilla/5.0',
    'Referer': 'https://nettruyenvio.com',
  };

  Future<List<Comic>> fetchComics() async {
    try {
      final resp = await _client.get(
        Uri.parse('https://nettruyenvio.com'),
        headers: _baseHeaders,
      );
      if (resp.statusCode != 200) {
        throw Exception('Failed to load homepage (${resp.statusCode})');
      }
      final doc = parse(resp.body);
      final items = doc.querySelectorAll('.items .item');

      return items.map((item) {
        final link = item.querySelector('.image a');
        final img = item.querySelector('img');
        final titleEl = item.querySelector('figcaption h3 a');
        
        if (link == null || img == null || titleEl == null) {
          throw Exception('Missing required elements in comic item');
        }

        final href = link.attributes['href'] ?? '';
        if (!href.contains('truyen-tranh')) {
          throw Exception('Not a comic link: $href');
        }

        final title = titleEl.text.trim();
        final thumb = img.attributes['data-original'] ??
            img.attributes['data-src'] ??
            img.attributes['src'] ?? '';

        return Comic(
          title: title,
          imageUrl: thumb,
          detailUrl: href,
        );
      }).where((comic) => comic.detailUrl.contains('truyen-tranh')).toList();
    } on SocketException catch (e) {
      print('Network error: $e');
      throw Exception('Failed to load homepage');
    } catch (e) {
      print('Other error: $e');
      throw Exception('Failed to load homepage');
    }
  }

  /// Parses the detail page to get all chapter URLs.
  /// Fetch the full list of chapter URLs via the site's JSON endpoint.
  /// Given a detail page like
  ///   https://…/truyen-tranh/{comicSlug}
  /// this will hit the JSON endpoint
  ///   …/Comic/Services/ComicService.asmx/ChapterList?slug={comicSlug}
  /// parse the returned payload, then build and return the
  /// full detail-URL for each chapter.
  Future<List<String>> fetchChapters(String detailUrl) async {
    try {
      // Always fetch fresh data from network
      final chapters = await _fetchChaptersFromNetwork(detailUrl);
      return chapters;
    } catch (e) {
      print('Error fetching chapters: $e');
      rethrow;
    }
  }

  /// Internal method to fetch chapters from network
  Future<List<String>> _fetchChaptersFromNetwork(String detailUrl) async {
    // 1. extract the slug ("every-day-in-a-vampire-family", etc)
    final uri = Uri.parse(detailUrl);
    final segments = uri.pathSegments;
    if (segments.length < 2) {
      throw FormatException('Unexpected detailUrl format: $detailUrl');
    }
    final comicSlug = segments.last;

    // 2. call the AJAX endpoint
    final api = Uri.parse(
      '$_base/Comic/Services/ComicService.asmx/ChapterList?slug=$comicSlug',
    );
    final resp = await http.get(api, headers: {
      'Referer': _base,
      'User-Agent': 'Mozilla/5.0',
      'Accept': 'application/json',
    });
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to load chapter list (${resp.statusCode}): ${resp.body}');
    }

    // 3. decode the JSON you supplied
    final Map<String, dynamic> jsonBody = json.decode(resp.body);
    final List data = jsonBody['data'] as List<dynamic>;

    // 4. build each chapter URL
    final chapters = data.map<String>((e) {
      final slug = e['chapter_slug'] as String;
      return '$_base/truyen-tranh/$comicSlug/$slug';
    }).toList();

    // 5. invert the list so Chapter 1 comes first
    return chapters.reversed.toList();
  }

  /// Fetches a chapter page and returns the list of image URLs.
  /// Optionally calls [onImageFound] for each image as it's discovered.
  Future<List<String>> fetchChapterPages(
    String chapterUrl, {
    Function(String imageUrl)? onImageFound,
  }) async {
    final resp = await _client.get(
      Uri.parse(chapterUrl),
      headers: _baseHeaders,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load chapter (${resp.statusCode})');
    }
    final doc = parse(resp.body);
    final imgs = doc.querySelectorAll('.page-chapter img');
    
    final imageUrls = <String>[];
    for (final img in imgs) {
      final imageUrl = img.attributes['data-src'] ?? img.attributes['src'] ?? '';
      if (imageUrl.isNotEmpty) {
        imageUrls.add(imageUrl);
        // Call the callback for each image as it's found
        onImageFound?.call(imageUrl);
      }
    }
    
    return imageUrls;
  }

  void dispose() {
    _client.close();
  }



  /// 🔥 Now requires context so we can solve/replay CF cookies
  /// Search comics by keyword on NetTruyen.
  ///
  /// [keyword] – the text the user typed.
  /// [cookie]  – OPTIONAL header string that contains cf_clearance and friends.
  ///             Pass the value returned from CloudflareHelper.ensureCookie().
  /// Search comics, popping Cloudflare bypass UI if needed.
  Future<List<Comic>> searchComics(String keyword) async {
    final completer = Completer<List<Comic>>();
    final searchUrl =
        'https://nettruyenvio.com/tim-truyen?keyword=${Uri.encodeComponent(keyword)}';

    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(searchUrl),
        headers: {
          'Referer': 'https://nettruyenvio.com',
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
      ),

      // If Cloudflare blocks us:
      onReceivedHttpError: (controller, request, errorResponse) {
        if (errorResponse.statusCode == 403 && !completer.isCompleted) {
          completer.completeError(CloudflareException(searchUrl));
        }
      },

      onLoadStop: (controller, _) async {
        // If already errored, skip
        if (completer.isCompleted) return;

        try {
          // give JS a moment
          await Future.delayed(Duration(seconds: 2));

          const js = r"""
            (function() {
              const items = document.querySelectorAll('.items .item');
              const results = [];
              items.forEach(item => {
                const link = item.querySelector('.image a');
                const thumbImg = item.querySelector('img');
                const titleEl = item.querySelector('figcaption h3 a');
                if (!link || !thumbImg || !titleEl) return;
                const thumb = thumbImg.getAttribute('data-original')
                             || thumbImg.getAttribute('data-src')
                             || thumbImg.src;
                results.push({
                  title: titleEl.textContent.trim(),
                  href: link.href.trim(),
                  thumb: thumb.trim()
                });
              });
              return JSON.stringify(results);
            })();
          """;

          final raw = await controller.evaluateJavascript(source: js) as String;
          final List data = json.decode(raw);
          final comics = data.map<Comic>((m) => Comic(
            title: m['title'],
            imageUrl: m['thumb'],
            detailUrl: m['href'],
          )).toList();

          completer.complete(comics);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },

      onConsoleMessage: (controller, msg) {
        print("SearchConsole: ${msg.message}");
      },
    );

    await headless.run();
    final result = await completer.future;
    await headless.dispose();
    return result;
  }

  /// Fetches detailed information about a comic from its detail page
  Future<Map<String, dynamic>> fetchComicDetails(String detailUrl) async {
    print('Fetching details from: $detailUrl');
    final resp = await _client.get(
      Uri.parse(detailUrl),
      headers: _baseHeaders,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load detail page (${resp.statusCode})');
    }
    final doc = parse(resp.body);

    // Get article details
    final article = doc.querySelector('article#item-detail');
    if (article == null) {
      print('Could not find article#item-detail');
      return {};
    }

    // Get title and update time
    final title = article.querySelector('h1.title-detail')?.text?.trim() ?? '';
    final updateTime = article.querySelector('time.small')?.text?.trim() ?? '';
    print('Found title: $title');
    print('Found update time: $updateTime');

    // Get details from list-info
    final listInfo = article.querySelector('ul.list-info');
    String? status;
    String? author;
    String? views;
    List<String> genres = [];

    if (listInfo != null) {
      // Get author
      final authorRow = listInfo.querySelector('li.author.row');
      if (authorRow != null) {
        final authorName = authorRow.querySelector('p.col-xs-8')?.text?.trim();
        if (authorName != null && authorName != 'Đang cập nhật') {
          author = authorName;
        }
      }

      // Get status
      final statusRow = listInfo.querySelector('li.status.row');
      if (statusRow != null) {
        status = statusRow.querySelector('p.col-xs-8')?.text?.trim();
      }

      // Get genres
      final kindRow = listInfo.querySelector('li.kind.row');
      if (kindRow != null) {
        genres = kindRow.querySelectorAll('a')
            .map((e) => e.text.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    print('Found author: $author');
    print('Found status: $status');
    print('Found genres: $genres');

    return {
      'title': title,
      'status': status,
      'author': author,
      'views': views,
      'genres': genres,
      'updateTime': updateTime,
    };
  }

  /// Updates a comic with its full details
  Future<Comic> updateComicWithDetails(Comic comic) async {
    try {
      // Try to get from database first
      final cached = await DatabaseHelper.instance.getComic(comic.detailUrl);
      if (cached != null) {
        print('Using cached comic details for: ${comic.title}');
        return cached;
      }

      // If not in database, fetch from network
      final details = await fetchComicDetails(comic.detailUrl);
      final updated = Comic(
        title: comic.title,
        imageUrl: comic.imageUrl,
        detailUrl: comic.detailUrl,
        status: details['status'],
        author: details['author'],
        views: details['views'],
        genres: List<String>.from(details['genres']),
        updateTime: details['updateTime'],
      );

      // Save to database
      final comicId = await DatabaseHelper.instance.insertComic(updated);
      print('Saved comic to database with id: $comicId');

      return updated;
    } catch (e) {
      print('Error updating comic details: $e');
      rethrow;
    }
  }

  /// Internal method to fetch chapters from network

}

Future<ImageProvider> fetchImageWithHeaders(String url) async {
  final response = await http.get(
    Uri.parse(url),
    headers: {
      'Referer': 'https://nettruyenvio.com',
      'User-Agent': 'Mozilla/5.0',
    },
  );
  if (response.statusCode == 200) {
    return MemoryImage(response.bodyBytes);
  } else {
    throw Exception('Failed to load image: ${response.statusCode}');
  }
}

class CustomNetworkImage extends StatelessWidget {
  final String imageUrl;
  const CustomNetworkImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: fetchImageWithHeaders(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return Image(image: snapshot.data!);
        } else if (snapshot.hasError) {
          return Icon(Icons.error);
        } else {
          return CircularProgressIndicator();
        }
      },
    );
  }
}