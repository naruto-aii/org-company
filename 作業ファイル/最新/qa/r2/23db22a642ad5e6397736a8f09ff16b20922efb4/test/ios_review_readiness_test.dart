import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final info = File('ios/Runner/Info.plist').readAsStringSync();
  final entitlements = File('ios/Runner/Runner.entitlements').readAsStringSync();
  final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  test('privacy manifest covers the required-reason APIs and collected data', () {
    expect(privacy, contains('<key>NSPrivacyTracking</key>'));
    expect(privacy, contains('<false/>'));
    expect(privacy, isNot(contains('<key>NSPrivacyTracking</key>\n\t<true/>')));
    expect(privacy, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    expect(privacy, contains('CA92.1'));
    expect(privacy, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
    expect(privacy, contains('C617.1'));
    expect(privacy, contains('0A2A.1'));
    expect(privacy, contains('NSPrivacyAccessedAPICategorySystemBootTime'));
    expect(privacy, contains('35F9.1'));
    expect(privacy, contains('NSPrivacyAccessedAPICategoryDiskSpace'));
    expect(privacy, contains('7D9E.1'));
    expect(privacy, isNot(contains('NSPrivacyAccessedAPICategoryActiveKeyboards')));
    expect(privacy, contains('NSPrivacyCollectedDataTypeEmailAddress'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeUserID'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeHealth'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeFitness'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeProductInteraction'));
    expect(privacy, contains('NSPrivacyCollectedDataTypePurchaseHistory'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeOtherUserContent'));
    expect(privacy, contains('NSPrivacyCollectedDataTypeOtherDataTypes'));
    expect(privacy, contains('NSPrivacyCollectedDataTypePurposeAnalytics'));
    expect(privacy, contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'));
    expect(
      privacy,
      isNot(contains('NSPrivacyCollectedDataTypePurposeProductPersonalization')),
    );
  });

  test('privacy manifest is a Runner resource and the app is iPhone-only', () {
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(
      project,
      contains(
        'A91B2C3D4E5F60718293A4B6 /* PrivacyInfo.xcprivacy in Resources */',
      ),
    );
    expect(project, isNot(contains('TARGETED_DEVICE_FAMILY = "1,2"')));
    expect('TARGETED_DEVICE_FAMILY = 1;'.allMatches(project).length, 6);
    expect(info, contains('NSHealthShareUsageDescription'));
    expect(
      info,
      contains(
        '生年月日、性別、身長、体重、アクティブエネルギー、ワークアウトを読み取り、カロリー目標の計算と記録の表示に使います。広告やマーケティングには使いません。',
      ),
    );
    expect(info, isNot(contains('NSHealthUpdateUsageDescription')));
    expect(info, isNot(contains('UISupportedInterfaceOrientations~ipad')));
    expect(info, contains('UIInterfaceOrientationPortrait'));
  });

  test('HealthKit entitlement is read access without clinical records', () {
    expect(entitlements, contains('com.apple.developer.healthkit'));
    expect(entitlements, contains('com.apple.developer.healthkit.access'));
    expect(entitlements, contains('<array/>'));
    expect(entitlements, isNot(contains('health-records')));
    expect(
      entitlements,
      isNot(contains('com.apple.developer.healthkit.background-delivery')),
    );

    final appSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in appSources) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('writeHealthData')), reason: file.path);
      expect(source, isNot(contains('HealthDataAccess.WRITE')), reason: file.path);
    }
  });
}
