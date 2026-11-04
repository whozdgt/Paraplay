# Publishing Paraplay on Google Play and the App Store

Where things stand against each store's rules, what the code and CI already take care of, and what only you can do
(accounts, payments, forms). Checked against the stores' published rules on 4 November 2026.

Legend: ✅ done in the app or CI · 👤 you do it in the store's console · ⚠️ needs a decision

## The builds

| | Workflow | What you get (run › Artifacts) |
|---|---|---|
| Google Play | `android` (job **play**) | `Paraplay-play-aab`: signed `.aab` to upload in Play Console |
| Phone APK from GitHub | `android` (job **sideload**) | unchanged: `Paraplay-android` + the `android-latest` release the app updates from |
| iPhone | `ios` | `Paraplay-ios-unsigned`: proves it builds; it must be signed to install (see below) |

Store builds are made with `-DPARAPLAY_STORE=ON` (always on for iOS). They have no self-updater, and the About page hides
the update settings, because both stores only allow updates through the store.

## Google Play

### Technical rules

| Rule | Status |
|---|---|
| Target Android 16 (API 36) for new apps and updates (since 31 Aug 2026) | ✅ target and compile SDK 36, Qt 6.10 |
| Upload an Android App Bundle (.aab) | ✅ `play` job builds and signs it; `bundletool validate` runs in CI |
| 64-bit native code | ✅ arm64-v8a |
| 16 KB memory pages for native code (apps targeting 15+) | ✅ linked with 16 KB pages; CI checks every `.so` and fails the Play build if one isn't aligned |
| No self-updating; no `REQUEST_INSTALL_PACKAGES` without a core need | ✅ removed from the Play manifest (CI fails if it comes back); updater code isn't compiled in |
| Android 15+ draws edge to edge | ✅ the app keeps clear of the status and gesture bars; bar icons follow your background colour |
| Android 16 predictive Back would close the app | ✅ opted out (`enableOnBackInvokedCallback="false"`) so Back still steps back |
| Media playback foreground service type declared | ✅ in the manifest · 👤 declare it in Play Console (below) |
| In-app account deletion | ✅ Profile › Delete account |
| Web page to delete an account without the app | ✅ `docs/delete-account.html` · 👤 turn on GitHub Pages |
| Privacy policy | ✅ `docs/privacy.html`, linked in the app (sign-in screen, Settings › About) · 👤 turn on GitHub Pages |

### Your steps

1. **Turn on GitHub Pages** (repo Settings › Pages › Deploy from a branch › `main` / `/docs`). The pages then live at
   `https://whozdgt.github.io/Paraplay/` (privacy.html, terms.html, delete-account.html). Open the delete page once
   and check it loads.
2. **Developer account** at play.google.com/console: one-time fee, identity check. A *personal* account made after
   13 Nov 2023 must run a **closed test with at least 12 testers, opted in for 14 days in a row**, before it can
   publish. Line up 12 people with Android phones early.
3. **Create the app**: name Paraplay, package `io.github.whozdgt.paraplay`, free.
4. **App signing**: Play re-signs the app with its own key. Your `ANDROID_KEYSTORE_BASE64` key signs the `.aab` as the
   *upload key*. ⚠️ Choice: let Play generate the app-signing key (simplest), or give Play your existing key
   ("use existing app signing key") so Play installs and GitHub APK installs can update each other. With Play's own
   key, someone switching between the two has to uninstall first (same package name, different signatures).
5. **App content** (Policy › App content):
   - Privacy policy URL: `https://whozdgt.github.io/Paraplay/privacy.html`
   - App access: social features need an account. Make a review account (username + password) and give it here.
   - Ads: no. Target audience: 13+ (not for children). Content rating: fill the IARC form; answer yes to
     "users can interact / share content" (profiles, bios, pictures, playlists).
   - **Foreground service**: type *mediaPlayback*, use case "Media playback". Needs a link to a short video
     (unlisted YouTube is fine) of starting a song, then locking the phone, with music continuing and the
     notification controls showing.
   - **Data safety**: see answers below. Account deletion: yes, web link
     `https://whozdgt.github.io/Paraplay/delete-account.html`.
6. **Store listing**: short and full description, app icon (`packaging/store/play-icon-512.png`), feature graphic
   1024×500, at least 2 phone screenshots.
7. Upload the `.aab` from the **play** job to the closed-testing track, add the testers, wait the 14 days, then apply
   for production.

### Data safety answers

All transfers use https. Nothing is used for ads or sold. Every item is optional (only with an account, or a setting
the person can turn off).

| Data type (Play's names) | Collected | Shared | Why |
|---|---|---|---|
| Personal info › User IDs (username, account id) | yes, optional | no | App functionality, account management |
| Photos and videos › Photos (profile picture, banner) | yes, optional | no | App functionality |
| App activity › Other user-generated content (bio, playlist names and songs, reports) | yes, optional | no | App functionality |
| App activity › Other actions (follows, blocks, "listening now" when shared) | yes, optional | no | App functionality |
| App activity › App interactions (song and artist names sent to lrclib.net and Deezer for lyrics and pictures) | ⚠️ yes, optional, processed ephemerally | ⚠️ yes, with lrclib and Deezer, not linked to the person | App functionality |

The last row is a judgement call: nothing is tied to the person, but declaring it is the safe reading of Play's
"sent off the device" rule.

## Apple App Store

### Technical rules

| Rule | Status |
|---|---|
| Built with Xcode 26 and the iOS 26 SDK (since 28 Apr 2026) | ✅ `ios` job selects Xcode 26 |
| Minimum iOS version | ✅ iOS 17 (Qt 6.10's minimum) |
| Privacy manifest (`PrivacyInfo.xcprivacy`) with reasons for "required reason" APIs | ✅ `packaging/ios/PrivacyInfo.xcprivacy`; CI checks it's in the app |
| App icon 1024×1024, no transparency | ✅ asset catalog from the existing icon |
| Purpose strings for system features | ✅ local network, photos; camera and microphone lines too (Qt Multimedia links that code; the app never asks) |
| Background audio | ✅ `UIBackgroundModes: audio`, playback audio session, lock-screen and Control Centre controls (`src/iosmedia.mm`) |
| Plain http only where needed | ✅ local network and media streams only; everything the app itself talks to is https |
| Export compliance | ✅ `ITSAppUsesNonExemptEncryption = NO` (standard https only) |
| No self-updating, no downloaded code | ✅ store build |
| Account deletion inside the app (5.1.1) | ✅ |
| User-generated content (1.2): report, block, terms with zero tolerance, contact, act on reports | ✅ report and block exist; terms shown at sign-up · 👤 review reports in the Supabase dashboard (`reports` table) within 24 hours |
| Music on an iPhone | ✅ the app's own folder appears in Files (On My iPhone › Paraplay) and in Finder; Settings › Library › Scan again; servers work as before |

### Not proven yet

The `ios` job compiles and packages the app, but nobody has run it on an iPhone. Expect a round of fixes after the
first TestFlight install: touch layout, the photo picker, playback continuing in the background, the lock-screen
controls.

### ⚠️ Licensing

Qt is linked statically into iOS apps. Qt is LGPLv3, and how its relinking and "installation information" terms
apply to App Store apps has never been settled. Paraplay is open source with its full build in this repository, which
covers relinking in practice, but the App Store's signing restrictions are the part people disagree about. The
alternative is a commercial Qt licence. Decide this before submitting; I'm not a lawyer. TagLib is also available
under MPL 1.1, which has no such problem.

### Your steps

1. **Apple Developer Program**: yearly fee. Enrolling as an individual is fine.
2. In App Store Connect: create the app with bundle id `io.github.whozdgt.paraplay`.
3. **Signing in CI** (I can add this once you have the account). Add these repository secrets:
   - `IOS_DIST_CERT_P12_BASE64` and `IOS_DIST_CERT_PASSWORD`: the Apple Distribution certificate
   - `IOS_PROFILE_BASE64`: the App Store provisioning profile for the bundle id
   - `IOS_TEAM_ID`
   - `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`: an App Store Connect API key, so CI can upload to TestFlight
4. **TestFlight**: install it on your iPhone and test. You can add up to 100 internal testers without a review.
5. **App Privacy** answers: data linked to the person, none used for tracking:
   - User ID
   - Photos
   - Other User Content
6. **Age rating**: answer the questionnaire. User-generated content is yes.
7. **App Review information**: give a review account (username + password) and note that the app plays the
   person's own files and servers.
8. **URLs**: privacy policy `https://whozdgt.github.io/Paraplay/privacy.html`, support
   `https://whozdgt.github.io/Paraplay/`.
9. Screenshots for 6.9" and 6.5" iPhones.

## Both stores

- **Artist pictures come from Deezer's public API.** Read Deezer's API terms on use in apps before launch. The feature
  can be switched off, or removed from store builds, if their terms don't allow it.
- **Reports**: both stores expect you to act on them. They land in the `reports` table in Supabase.
- **Sideloading**: Android's developer verification for apps installed outside Play started in four countries on
  30 Sep 2026 and goes worldwide in 2027. Registering the package name with your Play developer account covers the
  GitHub APK too.
