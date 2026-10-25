// GENERATED from ViralEngine/funnel-kit/dart/test/install_attribution_test.dart — edit it there and run `npm run funnel:sync`.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:military_calisthenics_women/core/funnel/install_attribution.dart';

Future<InstallAttribution> _load(
  Future<String?> Function() read, {
  Map<String, Object> prefs = const {},
  bool android = true,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final a = InstallAttribution.instance..resetForTest();
  await a.load(readReferrer: read, isAndroid: android);
  return a;
}

void main() {
  test('reads the post code from the smart-link referrer', () {
    expect(
      InstallAttribution.parse(
        'utm_source=facebook&utm_medium=post&utm_campaign=p_f3hnfms&utm_content=f3hnfms',
      ),
      'f3hnfms',
    );
    // Campaign only, upper case, still URL-encoded.
    expect(InstallAttribution.parse('utm_campaign=p_T3K9X2A'), 't3k9x2a');
    expect(
      InstallAttribution.parse('utm_source%3Dtiktok%26utm_content%3Dt3k9x2a'),
      't3k9x2a',
    );
  });

  test('no code for organic, bio-link or junk referrers', () {
    for (final r in [
      null,
      '',
      'utm_source=google-play&utm_medium=organic',
      'utm_source=tiktok&utm_medium=bio&utm_campaign=ve_bio',
      'utm_content=x3hnfms', // not a platform letter
      'utm_content=f3hnfmsz', // too long
      '%%%',
    ]) {
      expect(InstallAttribution.parse(r), isNull, reason: '$r');
    }
  });

  test('saves the code and passes it as the purchase profile id', () async {
    var reads = 0;
    final a = await _load(() async {
      reads++;
      return 'utm_content=y0abc12';
    });
    expect(a.postCode, 'y0abc12');
    expect(a.obfuscatedProfileId, 've_y0abc12');
    // Play needs an account id with a profile id: random, per install.
    final account = a.obfuscatedAccountId;
    expect(account, matches(RegExp(r'^[0-9a-f]{32}$')));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('funnel.post_code.v1'), 'y0abc12');

    // Later launches use the saved code without asking Play again.
    a.resetForTest();
    await a.load(
      readReferrer: () async {
        reads++;
        return null;
      },
      isAndroid: true,
    );
    expect(a.obfuscatedProfileId, 've_y0abc12');
    expect(a.obfuscatedAccountId, account);
    expect(reads, 1);
  });

  test('Play unavailable: retried on later launches, then given up', () async {
    var reads = 0;
    Future<String?> fail() async {
      reads++;
      throw Exception('SERVICE_UNAVAILABLE');
    }

    final a = await _load(fail);
    expect(a.postCode, isNull);
    for (var i = 0; i < 6; i++) {
      a.resetForTest();
      await a.load(readReferrer: fail, isAndroid: true);
    }
    expect(reads, 5);
  });

  test('never asks Play on iOS', () async {
    var reads = 0;
    final a = await _load(() async {
      reads++;
      return 'utm_content=t3k9x2a';
    }, android: false);
    expect(reads, 0);
    expect(a.obfuscatedProfileId, isNull);
    expect(a.obfuscatedAccountId, isNull);
  });
}
