# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Rayna is a hydration-reminder app (a cartoon stingray) for the macOS menu bar, iPhone/iPad, Apple Watch and widgets. Swift + SwiftUI, no third-party dependencies.

## Commands

```sh
swift build                                   # build RaynaCore + the macOS menu-bar executable
swift test                                    # RaynaCoreTests (XCTest)
swift test --filter SyncLedgerTests/testSettingsLastWriterWins   # one test
./build.sh                                    # release Rayna.app (ad-hoc signed, no iCloud); always launch the .app, not the .build binary

cd iOS && xcodegen generate                   # regenerate Rayna.xcodeproj after editing iOS/project.yml (both are committed)
cd iOS && xcodebuild -project Rayna.xcodeproj -scheme Rayna -destination 'generic/platform=iOS' build
cd iOS && xcodebuild -project Rayna.xcodeproj -scheme RaynaMac -destination 'generic/platform=macOS' build
iOS/scripts/mac-app-store.sh                  # archive + export the Mac App Store .pkg into builds/
```

The iOS archive/export commands are in README.md. App Store screenshots: `iOS/scripts/screenshots.sh <udid>:<folder>` (uses `RAYNA_*` demo env vars, see below).

## Architecture

**Targets and what they share**
- `Sources/RaynaCore` (SwiftPM library): everything platform-neutral, including the store, sync, pods, quips, ray facts, badges/accessories, the animated ray (PNG frame clips in `Resources/RaynaFrames`) and sounds. Uses `#if os(iOS)` / `#if os(macOS)` where needed.
- `Sources/Rayna`: the macOS menu-bar app. It is built **twice**: as the SwiftPM executable by `./build.sh` (ad-hoc DMG, no CloudKit; pods show a notice) and as the `RaynaMac` Xcode target (sandboxed Mac App Store build with iCloud). Changes to this folder affect both.
- `iOS/Rayna` (app), `iOS/RaynaWidget` (widgets + Live Activity), and `iOS/Shared` (App Intent + ActivityAttributes used by app and widget) link RaynaCore.
- `iOS/RaynaWatch` and `iOS/RaynaWatchWidget` do **not** link RaynaCore. They share only `iOS/WatchShared/WatchShared.swift` (keys, band thresholds) and get data from the iPhone over WatchConnectivity (`iOS/Rayna/WatchSync.swift`). Anything the Watch needs from core must be duplicated there.
- The Mac App Store build uses the iOS bundle id `co.versantus.raynawater.ios` (Universal Purchase). App Group `group.co.versantus.raynawater`; CloudKit container `iCloud.co.versantus.raynawater`.

**Local state.** `RaynaStore` (today's intake) and `RaynaExtras` (history, unlocks, streaks, swaps, settings) are thin wrappers over `UserDefaults`: the App Group suite on iOS (shared with widgets), standard defaults on macOS. Both take an injectable `defaults:` for tests.

**iCloud sync** (private database) is split into:
- `RaynaSyncLedger.swift`: pure merge model, no CloudKit, fully unit-tested. Days are glass events by id with undo tombstones (union); settings are last-writer-wins per key; the profile merges unions/max. Merges must stay commutative, associative and idempotent.
- `RaynaCloudSync.swift`: CloudKit I/O. Records `RaynaDay` (`day-yyyy-MM-dd`), `RaynaPrefs` (`prefs`), `RaynaProfile` (`profile`), each with a JSON `payload`.
- New synced settings go **inside the existing JSON payloads** (e.g. `glassML`, `mainLayout`, `wornSet`), not as new CloudKit fields. Decoding must tolerate missing/unknown keys, because older builds and the Mac still read the same payload.

**Pods** (`PodService.swift`, `PodInvites.swift`, `PodJoin.swift`): CloudKit sharing. Zone `RaynaPod` with `Pod` (root, shared via CKShare), `Member`, `Nudge`; read with `recordZoneChanges`, so no indexes. Schema is in `cloudkit/schema.ckdb`. Production never auto-creates record types; see `cloudkit/README.md` and `docs/TESTING-PODS.md` (Development vs Production environments can't see each other's pods). `PodService.shared` is main-actor.

**Feature flags and debug hooks.** Kid mode is built but hidden behind `RaynaFeatures.kidMode` (RaynaExtras.swift). Debug builds read `RAYNA_DEMO`, `RAYNA_STREAK`, `RAYNA_POD`, `RAYNA_BADGES`, `RAYNA_JOURNEY` and other `RAYNA_*` env vars for screenshots and testing; keep these `#if DEBUG`.

**Legacy names.** The exercise-day bonus is stored as `runDay`, `runBonusML`, `healthRunDay`, `healthAutoRun`, `liveActivityRunDay`, and the badge ids are `headband`/`medal`. UI copy now says "exercise day" / "Workout". Don't rename the stored keys.

## Conventions

- Copy must be child-friendly: no alcohol, innuendo, diet/body talk or medical claims (the swap challenge is "fizzy drink", not pint). Status lines live in `QuipLines.swift`.
- Keep iPhone and Mac in parity (glass presets, pod screen, settings order/labels). The parity table and design notes are in `docs/V1.1-NOTES.md`.
- Add user-visible changes to `CHANGELOG.md` under "Unreleased". Commit messages are short plain-English sentences ("Let Rayna wear one badge on her head, chest and fin.").
- Versions: macOS DMG version is in `build.sh` (Info.plist heredoc); iOS/Watch/MAS versions are in `iOS/project.yml` (`RaynaMac` overrides `MARKETING_VERSION`).
