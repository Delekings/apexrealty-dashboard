# Lintel iOS — Codemagic Build & Ship: Problems, Causes, and the Working Setup

> Save location: `docs/ios-codemagic-runbook.md`
> Last validated: 2026-06-26 (Techforge Developers Limited)

## The short version

Two independent walls, each wearing several disguises:

1. **A compile error** from a transitive PDF package incompatible with your Flutter version.
2. **A signing/export chain** that failed because there was never a usable distribution certificate + provisioning profile, and because `flutter build ipa` won't export an IPA without an explicit, profile-named export options plist.

Each looked like multiple different errors as we peeled layers, which is why it took ~16 builds. Below is each problem, why it happened, the false fixes, and the real fix.

## Problem 1 — The compile error (`pdf_widget_wrapper`)

**Symptoms (changed as we poked it):**
- `Error: No named parameter with the name 'size'` (pdf_widget_wrapper 1.0.0)
- `Error: Member not found: 'ViewConfiguration.fromView'` (pdf_widget_wrapper 1.0.4)

**Root cause:** The `printing` package pulls a transitive dependency, `pdf_widget_wrapper`. Different versions target different Flutter SDK APIs. Your Mac runs **Flutter 3.19.6**. Version 1.0.0 was too old (used a removed `size:` param); 1.0.4 was too new (used `ViewConfiguration.fromView`, which doesn't exist in 3.19.6). Trapped between too-old and too-new.

**False fixes that wasted builds:**
- `dependency_overrides: pdf_widget_wrapper: ^1.0.4` — the **caret** let the resolver keep picking 1.0.4. Carets on a pinned-down dependency defeat the purpose.
- Bumping `printing`/`pdf` up — needed Flutter 3.22, which your Mac can't run.

**The real fix:** Pin `printing` to a version old enough that it **doesn't depend on `pdf_widget_wrapper` at all**:
```yaml
  pdf: 3.10.7
  printing: 5.11.1
```
Remove the `dependency_overrides` block entirely. Verify:
```
flutter pub get
grep pdf_widget_wrapper pubspec.lock   # must print NOTHING
```
The package vanished from the lockfile -> the error vanished for good.

**Lesson:** When a transitive dependency won't compile, don't chase its version — eliminate it by pinning its *parent* to a version that doesn't pull it. And commit `pubspec.lock`: Codemagic builds from the lock, so a fix only counts once the lockfile is committed and pushed.

## Problem 2 — Signing kept reverting to automatic

**Symptom:** `Automatically signing iOS for device deployment... Automatic signing is disabled and unable to generate a profile. No profiles for 'dev.thetechforge.lintel' were found.`

**Root cause:** The Xcode project (`ios/Runner.xcodeproj`) had the Runner target on **automatic** signing. `flutter build ipa` honored that and tried to auto-generate a profile, which fails in CI.

**The fix (two parts):**
- In `codemagic.yaml`, use the `ios_signing` environment block + `xcode-project use-profiles` so Codemagic installs the right profile and forces manual signing.
- In `ios/Runner.xcodeproj/project.pbxproj`, in the **Runner Release** build config, set:
```
CODE_SIGN_STYLE = Manual;
CODE_SIGN_IDENTITY = "Apple Distribution";
"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";
```
(Edited as plain text in IntelliJ — no Xcode needed.)

## Problem 3 — The real blocker: no usable certificate or profile existed

**Symptom (the smoking gun, from a debug step):**
```
Cannot save Signing Certificates without certificate private key
Did not find any certificates from specified locations
Did not find matching provisioning profiles for code signing!
- Provisioning Profiles: []
- Signing Certificate:
- Team Id:
```

**Root cause:** There was **no distribution certificate with a usable private key**, and **no provisioning profile** for the bundle ID. An earlier certificate had been created "by API Key," meaning its private key only ever existed on a since-wiped machine — Apple listed a cert nobody could sign with. And no profile for `dev.thetechforge.lintel` had ever been generated (only one for an unrelated app, `glowhub`).

`app-store-connect certificates create` in the build couldn't fix it — it refused to mint a new cert (hit the 2-cert limit / couldn't store the key), so every "create" was a no-op.

**The real fix (one-time, persistent assets):**
1. **Revoke** the orphaned, keyless Distribution certificate in the Apple Developer portal.
2. **Generate a new distribution certificate inside Codemagic** (Settings -> Code signing identities -> iOS certificates -> Generate). Codemagic keeps the private key on its side and reuses it every build. Named `lintel_distribution`.
3. **Create the provisioning profile in the Apple Developer portal** (Profiles -> + -> App Store -> App ID `dev.thetechforge.lintel` -> select the distribution cert -> name it **`Lintel App Store`** -> Generate -> Download).
4. Upload that `.mobileprovision` to Codemagic (iOS provisioning profiles).

Now both halves — cert (with private key) and profile — live persistently in your account.

**Lesson:** "No profile found" almost always means the **certificate or profile genuinely doesn't exist with a usable private key** — not that the YAML is wrong. Generate the cert in Codemagic (so the key persists), create the profile in the Apple portal, and the build just consumes them.

## Problem 4 — Archive built, but no IPA exported (the silent one)

**Symptom:** Build went green, but TestFlight showed "No Builds." Logs showed `Built ...Runner.xcarchive`, then `Building App Store IPA... 835ms` (suspiciously fast), then no `build/ios/ipa` folder. Later, explicitly: `exportArchive "Runner.app" requires a provisioning profile`. Publishing said `No artifacts were found`.

**Root cause:** Two stacked issues:
- `flutter build ipa` **archives** then **exports**; the export half produced nothing because Flutter's auto-generated export options came up empty (no team, no profile).
- Even when forced, the export didn't know **which profile** to embed.

**The real fix:** Provide an **explicit export options plist that names the profile**, and pass it to `flutter build ipa`. The `provisioningProfiles` mapping (`bundle id -> profile name`) is the keystone. With it, the export ran in 3.8s and produced `build/ios/ipa/lintel.ipa`.

**Lesson:** "Archive succeeds but no IPA" = the export step has no valid signing context. Hand it an explicit plist that names the team and the exact profile.

## Problem 5 — Publishing did nothing (then worked)

**Symptom:** The `publishing.app_store_connect` block ran in `< 1s` with an empty log; nothing reached TestFlight.

**Root cause:** It silently no-op'd because there was no IPA to upload (Problem 4). Once the IPA existed, an explicit upload step worked.

**The real fix:** Upload the exported IPA explicitly:
```yaml
      - name: Upload to App Store Connect
        script: |
          IPA=$(find build/ios/ipa -name "*.ipa" | head -1)
          app-store-connect publish --path "$IPA"
```
Result: `UPLOAD SUCCEEDED with no errors` -> build appeared in TestFlight as "Processing."

## The final working codemagic.yaml

```yaml
# Codemagic CI/CD — Lintel (Techforge Developers Limited)
workflows:
  ios-release:
    name: Lintel iOS Release
    instance_type: mac_mini_m2
    max_build_duration: 90
    integrations:
      app_store_connect: Codemagic API Key
    environment:
      flutter: 3.19.6
      xcode: latest
      cocoapods: default
      ios_signing:
        distribution_type: app_store
        bundle_identifier: dev.thetechforge.lintel
      vars:
        APP_STORE_APPLE_ID: 6784547677
        BUNDLE_ID: "dev.thetechforge.lintel"
    scripts:
      - name: Flutter packages
        script: flutter pub get
      - name: Set up code signing
        script: xcode-project use-profiles
      - name: Pod install
        script: find . -name "Podfile" -execdir pod install \;
      - name: Create export options
        script: |
          cat > /tmp/export.plist <<'PLIST'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key><string>app-store</string>
            <key>teamID</key><string>2SY29F99Q9</string>
            <key>signingStyle</key><string>manual</string>
            <key>provisioningProfiles</key>
            <dict>
              <key>dev.thetechforge.lintel</key>
              <string>Lintel App Store</string>
            </dict>
            <key>uploadBitcode</key><false/>
            <key>uploadSymbols</key><true/>
          </dict>
          </plist>
          PLIST
      - name: Build IPA
        script: |
          flutter build ipa --release --export-options-plist=/tmp/export.plist
          find build/ios/ipa -name "*.ipa" || echo "NO IPA"
      - name: Upload to App Store Connect
        script: |
          IPA=$(find build/ios/ipa -name "*.ipa" | head -1)
          app-store-connect publish --path "$IPA"
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
```

## The persistent assets (must exist; they do now)

- **App ID** `dev.thetechforge.lintel` (explicit, Team 2SY29F99Q9) — Apple portal.
- **Distribution certificate** `lintel_distribution` — generated **in Codemagic** (key persists). Expires 2027-06-26.
- **Provisioning profile** `Lintel App Store` (App Store type, bound to bundle ID + that cert) — created in Apple portal, uploaded to Codemagic. Expires 2027-06-26.
- **ASC API key** integration named exactly `Codemagic API Key`, role **App Manager**.

## The repeatable release (every future ship)

1. Bump the build number in `pubspec.yaml`: `version: 1.0.0+2` (must increase every upload).
2. Confirm deps: `flutter pub get` then `grep pdf_widget_wrapper pubspec.lock` (must be empty).
3. `git add pubspec.yaml pubspec.lock && git commit -m "bump" && git push origin main`.
4. Codemagic builds, signs, exports, uploads — automatically.
5. App Store Connect -> TestFlight: wait for "Processing" -> answer export compliance -> attach build on the Distribution page for review.

## Android (separate track)

iOS ships via Codemagic. Android is built **locally**:
```
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```
Then upload that `.aab` to Play Console manually (first release) or wire a separate Codemagic Android workflow later.

## Certificate / profile renewal (June 2027)

Both `lintel_distribution` and `Lintel App Store` expire 2027-06-26. To renew:
1. Codemagic -> Code signing identities -> Generate a new distribution certificate.
2. Apple portal -> Profiles -> + -> App Store -> bundle ID + new cert -> download -> upload to Codemagic.
3. If the profile name changes, update the `provisioningProfiles` mapping in the export plist.

## Diagnostic playbook (when a future build fails)

- **`No named parameter` / `ViewConfiguration`** -> PDF pin drifted; restore `printing: 5.11.1`, confirm empty `grep` of the lockfile.
- **`Automatically signing... disabled`** -> `ios_signing` block missing or pbxproj not manual.
- **`No profiles for ... were found`** -> profile missing/expired; recreate in Apple portal, upload to Codemagic.
- **`Cannot save Signing Certificates without private key`** -> cert orphaned/expired; regenerate in Codemagic.
- **Archive built, `NO IPA`** -> export options plist missing or wrong profile name; fix the `provisioningProfiles` mapping.
- **Upload no-op / "No artifacts"** -> no IPA was produced (fix the export first).
- **"duplicate build number" at upload** -> bump `+N`.

Two things you can't see from the YAML that matter most when stuck: whether the **certificate has a usable private key**, and whether a **profile actually exists for the exact bundle ID**. When in doubt, add a debug step that prints `security find-identity -v -p codesigning` and the installed profile names — that output ends the guessing.
