/// Details of this build, passed in by CI with `--dart-define`.
abstract final class BuildInfo {
  /// Short commit hash the build was made from.
  static const commit = String.fromEnvironment('SPEAKAGAIN_COMMIT');

  /// CI workflow run number, shown on the About screen of CI builds.
  static const ciRun = String.fromEnvironment('SPEAKAGAIN_CI_RUN');

  /// `release` for published builds, `ci` for test builds, empty for local ones.
  static const channel = String.fromEnvironment('SPEAKAGAIN_CHANNEL');

  static const repositoryUrl = 'https://github.com/lobojoel2003/Speakagain';
  static const packGuideUrl = '$repositoryUrl/blob/main/docs/packs.md';
  static const privacyUrl = '$repositoryUrl/blob/main/PRIVACY.md';

  /// Extra text after the version on the About screen.
  static String get details => [
    if (channel.isNotEmpty && channel != 'release') channel,
    if (ciRun.isNotEmpty) 'run $ciRun',
    if (commit.isNotEmpty) commit,
  ].join(' · ');
}
