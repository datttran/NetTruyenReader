import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comic.dart';
import '../screens/cloudflare_bypass_screen.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:html/dom.dart';



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
  Future<List<Comic>> searchComics(BuildContext context, String query) async {
    final searchUrl = 'https://nettruyenvio.com/tim-truyen?keyword=${Uri.encodeComponent(query)}';
    final prefs = await SharedPreferences.getInstance();
    String cookie = prefs.getString('cookie') ?? '';


    print(cookie.contains('cf_clearance='));
    print('so be it');




    http.Response response = await _client.get(
      Uri.parse(searchUrl),
      headers: {
        'Referer': 'https://nettruyenvio.com',
        'User-Agent': _userAgent,
        'Cookie': cookie,
      },
    );

    print('RESPONSE START:');
    print(response.body.substring(0, 500));
    print('RESPONSE END.');

    if (response.statusCode == 403 ||
        response.body.contains('cf_chl_opt') ||
        response.body.contains('Attention Required')) {
      print('⚡ Cloudflare challenge detected. Opening bypass screen...');

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CloudflareBypassScreen(url: searchUrl),
        ),
      );

      if (result == true) {
        print('✅ Verification successful. Retrying search request with new cookies...');

        final prefsAfter = await SharedPreferences.getInstance();
        final updatedCookie = prefsAfter.getString('cookie') ?? '';

        response = await _client.get(
          Uri.parse(searchUrl),
          headers: {
            'Referer': 'https://nettruyenvio.com',
            'User-Agent': _userAgent,
            'Cookie': updatedCookie,
          },
        );

        if (response.statusCode != 200) {
          throw Exception('Retry search failed after Cloudflare verification.');
        }
      } else {
        throw Exception('Cloudflare verification failed.');
      }
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to load search results. Status code: ${response.statusCode}');
    }

    final doc = html_parser.parse(response.body);
    final items = doc.querySelectorAll('div.item');
    List<Comic> results = [];

    for (var item in items) {
      try {
        final aTag = item.querySelector('div.image > a');
        final imgTag = item.querySelector('div.image > a > img');

        if (aTag == null || imgTag == null) continue;

        final title = aTag.attributes['title'] ?? '';
        final detailUrl = aTag.attributes['href'] ?? '';
        final imageUrl = imgTag.attributes['data-original'] ?? imgTag.attributes['src'] ?? '';

        if (title.isNotEmpty && detailUrl.isNotEmpty && imageUrl.isNotEmpty) {
          results.add(Comic(
            title: title.trim(),
            detailUrl: detailUrl.trim(),
            imageUrl: imageUrl.trim(),
          ));
        }
      } catch (e) {
        print('Error parsing a comic item: $e');
      }
    }

    return results;
  }

}
