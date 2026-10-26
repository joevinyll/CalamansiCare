import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('Android delegates OAuth callbacks to Supabase app_links', () {
    final manifest = XmlDocument.parse(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync());
    final activity = manifest.findAllElements('activity').single;
    final flag = activity.findElements('meta-data').singleWhere((element) =>
        element.getAttribute('android:name') == 'flutter_deeplinking_enabled');
    expect(flag.getAttribute('android:value'), 'false');
    final callback = activity.findAllElements('data').singleWhere(
        (element) => element.getAttribute('android:host') == 'login-callback');
    expect(
        callback.getAttribute('android:scheme'), 'io.supabase.calamansicare');
  });

  test('iOS registers the OAuth scheme and delegates deep links', () {
    final plist =
        XmlDocument.parse(File('ios/Runner/Info.plist').readAsStringSync());
    final values =
        plist.rootElement.findElements('dict').single.childElements.toList();
    final flag = values.indexWhere((element) =>
        element.name.local == 'key' &&
        element.innerText == 'FlutterDeepLinkingEnabled');
    expect(flag, greaterThanOrEqualTo(0));
    expect(values[flag + 1].name.local, 'false');
    final types = values.indexWhere((element) =>
        element.name.local == 'key' && element.innerText == 'CFBundleURLTypes');
    expect(types, greaterThanOrEqualTo(0));
    expect(values[types + 1].findAllElements('string').map((e) => e.innerText),
        contains('io.supabase.calamansicare'));
  });
}
