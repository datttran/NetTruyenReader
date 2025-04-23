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




final String _baseUrl = 'https://nettruyenvio.com';


/// Thrown when Cloudflare returns a 403 on our search URL.
class CloudflareException implements Exception {
  final String url;
  CloudflareException(this.url);
}


class NetTruyenService {
  static final http.Client _client = http.Client();  // <-- Fix 1: define _client
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'; // <-- Fix 2: define _userAgent
  /// Fetch comics by loading JS-rendered page in a headless WebView
  Future<List<Comic>> fetchComics() async {
    final completer = Completer<List<Comic>>();


    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('https://nettruyenvio.com'),
        headers: {
          'Referer': 'https://nettruyenvio.com',
          'User-Agent': 'Mozilla/5.0',
        },
      ),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
      ),
      onLoadStop: (controller, url) async {
        try {
          // Allow JS-driven lazy-loading to finish
          await Future.delayed(Duration(seconds: 5));
          final pageTitle = await controller.getTitle();
          print('Headless page title: $pageTitle');

          // JS snippet: find <a[title]> anchors linking to comics and grab real thumbnail
          const js = r"""
            (function(){
              const anchors = Array.from(document.querySelectorAll('a[title]'));
              const items = [];
              anchors.forEach(a => {
                if (!a.href.includes('/truyen-')) return;
                const img = a.querySelector('img');
                if (!img) return;
                // Use data-original for actual thumb, fallback to data-src or src
                const thumbUrl = img.getAttribute('data-original') || img.getAttribute('data-src') || img.src;
                items.push({
                  title: a.title.trim(),
                  thumb: thumbUrl,
                  href: a.href
                });
              });
              return JSON.stringify(items);
            })();
          """;

          final raw = await controller.evaluateJavascript(source: js);
          print('JS raw result: $raw');
          final List data = json.decode(raw as String);
          final comics = data.map<Comic>((m) => Comic(
            title: m['title'],
            imageUrl: m['thumb'],
            detailUrl: m['href'],
          )).toList();

          if (!completer.isCompleted) completer.complete(comics);
        } catch (e) {
          print('Error in fetchComics JS eval: $e');
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        print('Console: ${consoleMessage.message}');
      },
    );

    await headless.run();
    final result = await completer.future;
    await headless.dispose();
    return result;
  }

  /// Scrape chapter list via JS
  Future<List<String>> fetchChapters(String detailUrl) async {
    final completer = Completer<List<String>>();
    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(detailUrl),
        headers: {
          'Referer': 'https://nettruyenvio.com',
          'User-Agent': 'Mozilla/5.0',
        },
      ),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
      ),
      onLoadStop: (controller, url) async {
        try {
          await Future.delayed(Duration(seconds: 3));
          const js = r"""
            (function(){
              const els = document.querySelectorAll('.chapter-list a');
              return JSON.stringify(Array.from(els).map(a => a.href));
            })();
          """;
          final raw = await controller.evaluateJavascript(source: js);
          print('Chapters JS raw: $raw');
          final List data = json.decode(raw as String);
          final chapters = List<String>.from(data);
          if (!completer.isCompleted) completer.complete(chapters);
        } catch (e) {
          print('Error in fetchChapters JS eval: $e');
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        print('Console: ${consoleMessage.message}');
      },
    );

    await headless.run();
    final result = await completer.future;
    await headless.dispose();
    return result;
  }

  /// Scrape chapter pages via JS
  Future<List<String>> fetchChapterPages(String chapterUrl) async {
    final completer = Completer<List<String>>();
    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(chapterUrl),
        headers: {
          'Referer': 'https://nettruyenvio.com',
          'User-Agent': 'Mozilla/5.0',
        },
      ),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
      ),
      onLoadStop: (controller, url) async {
        try {
          await Future.delayed(Duration(seconds: 3));
          const js = r"""
            (function(){
              const imgs = document.querySelectorAll('.reading-detail img');
              return JSON.stringify(Array.from(imgs).map(img => img.getAttribute('data-src') || img.src));
            })();
          """;
          final raw = await controller.evaluateJavascript(source: js);
          print('Pages JS raw: $raw');
          final List data = json.decode(raw as String);
          final pages = List<String>.from(data);
          if (!completer.isCompleted) completer.complete(pages);
        } catch (e) {
          print('Error in fetchChapterPages JS eval: $e');
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        print('Console: ${consoleMessage.message}');
      },
    );

    await headless.run();
    final result = await completer.future;
    await headless.dispose();
    return result;
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
