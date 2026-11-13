# Releasing

## Version numbers

- The version is in [`pubspec.yaml`](../pubspec.yaml) as `version: MAJOR.MINOR.PATCH+BUILD` and
  follows [Semantic Versioning](https://semver.org):
  - **PATCH**: fixes only.
  - **MINOR**: new features or packs; settings and progress from earlier versions keep working.
  - **MAJOR**: changes that need people to do something when updating.
- The **build number** is derived from the version: `MAJOR × 10000 + MINOR × 100 + PATCH`
  (1.0.0 → 10000, 1.2.3 → 10203). It becomes the Android `versionCode` and the iOS
  `CFBundleVersion`, so every release installs as an update. MINOR and PATCH stay below 100.
  All Android APKs of one release share the build number (`-Pforce-version-code-ignoring-abi=true`).
- Release tags are `v` plus the version: `v1.0.0`.
- CI and release builds show the workflow run number and commit in **Settings › About Speakagain**
  (passed with `--dart-define`).
- `python3 tool/version.py check vX.Y.Z` runs the same checks as CI.

## Making a release

1. Make sure `main` is green in [CI](https://github.com/lobojoel2003/Speakagain/actions/workflows/ci.yml).
2. Update `version:` in `pubspec.yaml` (both parts: `1.1.0+10100`).
3. In [`CHANGELOG.md`](../CHANGELOG.md), rename **Unreleased** to `## [X.Y.Z] - YYYY-MM-DD`, add a
   new empty **Unreleased** section above it, and update the links at the bottom.
4. Commit (`release: X.Y.Z`) and push to `main`.
5. Start the release, either:
   - **from GitHub:** **Actions › Release › Run workflow** on `main`. The tag `vX.Y.Z` is created
     from `pubspec.yaml` together with the release; or
   - **with git:**

     ```bash
     git tag -a vX.Y.Z -m "Speakagain X.Y.Z"
     ```

     ```bash
     git push origin vX.Y.Z
     ```

The [Release workflow](../.github/workflows/release.yml) then:

1. runs the full CI;
2. checks the tag matches `pubspec.yaml` and that `CHANGELOG.md` has the section;
3. builds release APKs for `arm64-v8a`, `armeabi-v7a`, `x86_64` and a universal APK, and an App
   Bundle, signed with the project key; verifies the signature;
4. builds the web app (as a zip for any web server, and for GitHub Pages) and an unsigned iOS app;
5. publishes the GitHub Release with the changelog section, install instructions, the signing
   certificate's SHA-256 fingerprint, `SHA256SUMS.txt` and the files;
6. deploys the web app to GitHub Pages, if Pages is set to deploy from GitHub Actions
   (**Settings › Pages › Source › GitHub Actions**). Otherwise it leaves a notice and skips this step.

## Android signing key

Android only installs an update if it is signed with the same key as the installed app, so the
release key must stay the same forever. Keep a safe offline copy.

Create it once (on your own computer):

```bash
keytool -genkeypair -keystore speakagain-release.jks -storetype PKCS12 -alias speakagain -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Speakagain"
```

Then add these repository secrets (**Settings › Secrets and variables › Actions › New repository
secret**):

| Secret | Value |
|---|---|
| `SPEAKAGAIN_KEYSTORE_BASE64` | The keystore as base64: `base64 -w0 speakagain-release.jks` (macOS: `base64 -i speakagain-release.jks`) |
| `SPEAKAGAIN_KEYSTORE_PASSWORD` | The keystore password |
| `SPEAKAGAIN_KEY_ALIAS` | `speakagain` (or the alias you chose) |
| `SPEAKAGAIN_KEY_PASSWORD` | The key password (for PKCS12 keystores, the same as the keystore password) |

Without these secrets the workflow still publishes, but signs with a temporary key and says so in
the release notes. Installs from such a release can't be updated by a later release signed with the
project key; people would need to uninstall and reinstall (practice history is kept only on the
device).

To build a signed release locally, set `SPEAKAGAIN_KEYSTORE_FILE` (the keystore's path),
`SPEAKAGAIN_KEYSTORE_PASSWORD`, `SPEAKAGAIN_KEY_ALIAS` and `SPEAKAGAIN_KEY_PASSWORD`, then run
`flutter build apk --release`.

## iOS

The release includes an unsigned build for sideloading. To publish on the App Store, open
`ios/Runner.xcworkspace` in Xcode, set your team and bundle identifier, and archive. The build
number is already set from `pubspec.yaml`.

## Speech models and voices

The models the app downloads live in a separate release (`models-v1`), built by the
[Models workflow](../.github/workflows/models.yml). To change them (a new voice, a newer upstream
export):

1. Edit [`tool/models/sources.json`](../tool/models/sources.json) (pin the upstream archive's
   SHA-256).
2. Run `python3 tool/models/build_models.py` (with `pip install -r tool/models/requirements.txt`)
   and copy `build/models/catalog.json` to `assets/models/catalog.json`. If any file changed,
   raise `RELEASE_TAG` in `build_models.py` (`models-v2`) so existing apps keep their files.
3. Commit, push, and push the tag (`git tag models-v2 && git push origin models-v2`). The workflow
   rebuilds everything, fails unless it matches the committed catalog byte for byte, and publishes.
4. Release a new app version that contains the new catalog.

`python3 tool/models/check_catalog.py` (also in CI) checks every file in the catalog can be
downloaded with the right size.

## Updating pinned inputs

| What | Where |
|---|---|
| Flutter | `FLUTTER_VERSION` in `.github/workflows/*.yml` and the README |
| OpenMoji | `VERSION` and `SHA256` in `tool/sync_symbols.py`, then run it |
| Upstream models | `tool/models/sources.json` (see above) |
| Model build tools | `tool/models/requirements.txt` (changes the model bytes: needs a new models release) |
