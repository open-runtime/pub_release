import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:meta/meta.dart';
import 'package:pub_semver/pub_semver.dart';
import '../pubspec_helper.dart';
import '../release_runner.dart';

/// Returns the version no. for the pubspec.yaml located
/// at [pubspecPath].
/// Use [findPubSpec] to find the location.
///
Version? version({required String pubspecPath}) {
  final pubspec = PubSpec.fromFile(pubspecPath);
  return pubspec.version;
}

String versionPath(String pathToPackgeRoot) =>
    join(pathToPackgeRoot, 'lib', 'src', 'version');

String versionLibraryPath(String pathToPackgeRoot) =>
    join(versionPath(pathToPackgeRoot), 'version.g.dart');

/// Makes a backup copy of the version.g.dart source file.
void backupVersionLibrary(String pathToPackageRoot) {
  final versionLibrary = versionLibraryPath(pathToPackageRoot);
  backupFile(versionLibrary);
}

/// Restores the version.g.dart source from a back made
/// by an earlier call to [backupVersionLibrary]
void restoreVersionLibrary(String pathToPackageRoot) {
  final versionLibrary = versionLibraryPath(pathToPackageRoot);
  restoreFile(versionLibrary);
}

/// Updates the pubspec.yaml and versiong.g.dart with the
/// new version no.
void updateVersion(Version? newVersion, PubSpecDetails pubspecDetails) {
  print('');

  // recreate the version file
  final pathToPackgeRoot = dirname(pubspecDetails.path);

  print(green('Updated pubspec.yaml version to $newVersion'));

  // updated the verions no.
  pubspecDetails.pubspec.version = newVersion;

  // write new version.g.dart file.
  final pathToVersion = versionPath(pathToPackgeRoot);
  final pathToVersionLibrary = versionLibraryPath(pathToPackgeRoot);

  if (!exists(pathToVersion)) createDir(pathToVersion, recursive: true);
  print('Regenerating version file at ${absolute(pathToVersionLibrary)}');
  pathToVersionLibrary.write('/// GENERATED BY pub_release do not modify.');
  pathToVersionLibrary.append('/// ${pubspecDetails.pubspec.name} version');
  pathToVersionLibrary.append("String packageVersion = '$newVersion';");

  // rewrite the pubspec.yaml with the new version
  pubspecDetails.pubspec.saveToFile(pubspecDetails.path);
}

/// Ask the user to select the new version no.
/// Pass in  the current [currentVersion] number.
Version askForVersion(Version currentVersion) {
  final options = <_NewVersion>[
    _NewVersion('Small Patch'.padRight(25), currentVersion.nextPatch),
    _NewVersion('Non-breaking change'.padRight(25), currentVersion.nextMinor),
    _NewVersion('Breaking change'.padRight(25), currentVersion.nextBreaking),
    _NewVersion('Keep the current Version'.padRight(25), currentVersion),
    _CustomVersion('Enter custom version no.'.padRight(25))
  ];

  print('');
  print(blue('What sort of changes have been made since the last release?'));
  final selected = menu(prompt: 'Select the change level:', options: options);

  if (selected is _CustomVersion) {
    selected.requestCustomVersion();
  }

  return confirmVersion(selected.version);
}

/// Ask the user to confirm the selected version no.
Version confirmVersion(Version version) {
  var confirmedVersion = version;
  print('');
  print(green('The new version is: $confirmedVersion'));
  print('');

  if (!confirm('Is this the correct version')) {
    var valid = false;
    do {
      try {
        final versionString = ask('Enter the new version: ');

        if (!confirm('Is $versionString the correct version')) {
          exit(1);
        }

        confirmedVersion = Version.parse(versionString);
        valid = true;
      } on FormatException catch (e) {
        print(e);
      }
    } while (!valid);
  }
  return confirmedVersion;
}

/// Used by version menu to provide a nice message
/// for the user.
class _NewVersion {
  final String message;
  @protected
  Version _version;

  _NewVersion(this.message, this._version);

  @override
  String toString() => '$message  ($_version)';

  Version get version {
    return _version;
  }
}

/// Used by the version menu to allow the user to select a custom version.
/// When this classes [version] property is called it triggers
class _CustomVersion extends _NewVersion {
  @override
  _CustomVersion(String message) : super(message, Version.parse('0.0.1'));

  @override
  Version get version => _version;

  /// Ask the user to type a custom version no.
  void requestCustomVersion() {
    var valid = false;
    do {
      try {
        final entered =
            ask('Enter the new Version No.:', validator: Ask.required);
        _version = Version.parse(entered);
        valid = true;
      } on FormatException catch (e) {
        print(e);
      }
    } while (!valid);
  }
}
