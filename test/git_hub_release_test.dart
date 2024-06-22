import 'dart:io';

import 'package:dcli/dcli.dart' hide Settings;
import 'package:dcli_core/dcli_core.dart' as core;
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:pub_release/pub_release.dart';

void main() async {
  final settingsPath = truepath(join('test', 'settings.yaml'));
  print('loading settings from $settingsPath');

  final settings = Settings.loadFromPath(pathToSettings: settingsPath);

  if (settings.username == null) {
    print(red('username not set in settings.yaml'));
    exit(1);
  }

  if (settings.apiToken == null) {
    print(red('apiToken not set in settings.yaml'));
    exit(1);
  }

  if (settings.owner == null) {
    print(red('owner not set in settings.yaml'));
    exit(1);
  }

  final ghr = SimpleGitHub(
      username: settings.username!,
      apiToken: settings.apiToken!,
      owner: settings.owner!,
      repository: 'dcli')
    ..auth();

  const tagName = '0.0.3-test';

  /// update latest tag to point to this new tag.
  final old = await ghr.getReleaseByTagName(tagName: tagName);

  if (old != null) {
    print('replacing release $tagName');
    ghr.deleteRelease(old);
  } else {
    print('release not found');
  }

  // TODO update from main fork head eventually withTempDirAsync
  await core.withTempDirAsync((tempDir) async {
    final pathToProject = join(tempDir, 'aproject');
    final project =
        DartProject.create(pathTo: pathToProject, templateName: 'simple');
    (project..warmup()).compile();
    final exe = DartScript.fromFile(join(project.pathToBinDir, 'aproject.dart'))
        .pathToExe;

    print('Creating release: $tagName');
    var release = await ghr.release(tagName: tagName);

// 'application/vnd.microsoft.portable-executable'
    print('Sending Asset  $exe');
    ghr.attachAssetFromFile(
      release: release,
      assetPath: exe,
      assetName: 'test_exe',
      // assetLabel: 'DCli installer',
      mimeType: lookupMimeType('$exe.exe')!,
    );
    print('send complete');

    /// update latest tag to point to this new tag.
    final latest = await ghr.getReleaseByTagName(
        tagName: 'latest.${Platform.operatingSystem}');
    if (latest != null) {
      ghr.deleteRelease(latest);
    }

    release = await ghr.release(tagName: 'latest.${Platform.operatingSystem}');

// 'application/vnd.microsoft.portable-executable'
    print('Sending Asset');
    ghr.attachAssetFromFile(
      release: release,
      assetPath: exe,
      assetName: 'test_exe',
      // assetLabel: 'DCli installer',
      mimeType: lookupMimeType('$exe.exe')!,
    );
  });
  print('send complete');
}
