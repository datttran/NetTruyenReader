import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comic.dart';
import '../screens/cloudflare_bypass_screen.dart';

import 'package:http/http.dart' as http;


import 'package:html/parser.dart';

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


class NetTruyenService {

  /// Fetch comics by loading JS-rendered page in a headless WebView
  final _client = http.Client();
  static const _baseHeaders = {
    'User-Agent': 'Mozilla/5.0',
    'Referer': 'https://nettruyenvio.com',
  };

  /// Fetches the homepage and parses the list of comics.
  Future<List<Comic>> fetchComics() async {
    final resp = await _client.get(
      Uri.parse('https://nettruyenvio.com'),
      headers: _baseHeaders,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load homepage (${resp.statusCode})');
    }
    final doc = parse(resp.body);
    final anchors = doc
        .querySelectorAll('a[title]')
        .where((a) => a.attributes['href']?.contains('/truyen-') == true);

    return anchors.map((a) {
      final title = a.attributes['title']!.trim();
      final img = a.querySelector('img');
      final thumb = img?.attributes['data-original'] ??
          img?.attributes['data-src'] ??
          img?.attributes['src'] ?? '';
      return Comic(
        title: title,
        imageUrl: thumb,
        detailUrl: a.attributes['href']!,
      );
    }).toList();
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
    return data.map<String>((e) {
      final slug = e['chapter_slug'] as String;
      return '$_base/truyen-tranh/$comicSlug/$slug';
    }).toList();
  }

  /// Fetches a chapter page and returns the list of image URLs.
  Future<List<String>> fetchChapterPages(String chapterUrl) async {
    final resp = await _client.get(
      Uri.parse(chapterUrl),
      headers: _baseHeaders,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load chapter (${resp.statusCode})');
    }
    final doc = parse(resp.body);
    final imgs = doc.querySelectorAll('.page-chapter img');
    return imgs.map((img) {
      return img.attributes['data-src'] ?? img.attributes['src'] ?? '';
    }).toList();
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
}
