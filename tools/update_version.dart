#!/usr/bin/env dart

/// Script a version.json fájl automatikus frissítéséhez a pubspec.yaml alapján
///
/// Használat:
///   dart tools/update_version.dart
///
/// Ez a script:
/// - Beolvassa a pubspec.yaml verzióját
/// - Frissíti a web/version.json fájlt
/// - Frissíti a build/web/version.json fájlt (ha létezik)

import 'dart:io';
import 'dart:convert';

void main() async {
  try {
    // Pubspec.yaml beolvasása
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('❌ Error: pubspec.yaml not found');
      exit(1);
    }

    final pubspecContent = await pubspecFile.readAsString();

    // Verzió kinyerése
    final versionRegex = RegExp(r'^version:\s*(.+)$', multiLine: true);
    final match = versionRegex.firstMatch(pubspecContent);

    if (match == null) {
      print('❌ Error: Version not found in pubspec.yaml');
      exit(1);
    }

    final version = match.group(1)!.trim();
    final buildDate = DateTime.now().toIso8601String().split('T')[0];

    print('📦 Version found: $version');
    print('📅 Build date: $buildDate');

    // Version JSON objektum
    final versionJson = {
      'version': version,
      'buildDate': buildDate,
    };

    final jsonContent = const JsonEncoder.withIndent('  ').convert(versionJson);

    // web/version.json írása
    final webVersionFile = File('web/version.json');
    await webVersionFile.writeAsString('$jsonContent\n');
    print('✅ Updated: web/version.json');

    // build/web/version.json írása (ha létezik a build mappa)
    final buildWebDir = Directory('build/web');
    if (buildWebDir.existsSync()) {
      final buildVersionFile = File('build/web/version.json');
      await buildVersionFile.writeAsString('$jsonContent\n');
      print('✅ Updated: build/web/version.json');
    }

    print('');
    print('🎉 Version update completed successfully!');
    print('   Version: $version');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
