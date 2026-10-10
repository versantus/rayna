# Changelog

All notable changes to Rayna (macOS menu-bar app + iOS app). macOS versions are listed; the iOS app ships as 1.0 (unreleased).

## 2.2.0: 2026-10-10

### Phase D
- **Apple Watch app (watchOS 10+):** big "+1 glass", progress ring, Rayna still by band, synced with the iPhone via WatchConnectivity (application context + messages/queued userInfo). Watch complication (circular/rectangular/corner/inline).
- **Run-day Live Activity (optional toggle):** Lock Screen + Dynamic Island progress with a +1 button. Starts when run day is on, ends at goal or when run day is turned off.

### Phase C
- **Pods (CloudKit sharing, container iCloud.co.versantus.rayna):** "Start a pod" creates a zone + root record + CKShare (anyone with the link can join). Members publish daily glasses/ml/goal/streak. The shared tank shows everyone's Rayna at their own water level, with "Nudge 👋" (max 3 per person per day; delivered as a local notification after a silent CKDatabaseSubscription push) and a pod streak when everyone hits their goal. Works on iOS and macOS; on macOS it needs an iCloud-entitled signed build (the ad-hoc DMG shows a notice instead).

### Phase B
- **Share cards:** 1080×1920 story and 1080×1080 square cards (Rayna celebrating, stats, rayna-water.netlify.app), rendered with ImageRenderer. Offered on goal, from unlock celebrations and from the weekly recap (streak card). iOS uses ShareLink; macOS uses NSSharingServicePicker. Video share skipped.
- **Apple Health (iOS):** optional auto run day from today's running workouts (+500 ml, +250 ml per extra 30 min past an hour, max +1,000 ml), and optional Dietary Water logging (Undo removes it). Only the permissions for enabled options are requested. Garmin isn't connected directly; it syncs through Apple Health.

### Phase A
- **Rayna evolves:** streak unlocks drawn in code over the animated Rayna: 3 days bubble trail 🫧, 7 days run-day headband 🎽, 14 days race medal 🏅, 30 days baby ray buddy 🐣. Unlock celebration card with confetti, plus a collection screen ("Rayna's journey").
- **Swap-a-pint:** optional evening challenge after 18:00. "I swapped a drink for water" logs a swap and a glass, with its own streak and stats and gentle copy. Toggle in Settings. The macOS evening nudge now has "I swapped one 💧" / "Not tonight".
- **Weekly recap:** 7-day chart, total, daily average, best day, goals hit, streak/best streak, swaps, bathtub and paddling-pool fun facts.
- **iOS Lock Screen widgets:** accessoryCircular (ring), accessoryRectangular (Rayna + progress), accessoryInline.
- Goal quip now matches the new spin ("Happy spin deployed").

## 2.1.1: 2026-10-10
- Replaced the generated barrel roll with a code-driven 360° happy spin; the nudge's "Drank one" now plays wiggle then swim-off.
- Faster launch: frames decode lazily per clip off the main thread, and a still shows until they're ready.
- Refreshed App Store screenshots.

## 2.1.0: 2026-10-10
- Higgsfield-generated Rayna replaces the code-drawn stingray (PNG frame animations), icon B, menu-bar glyph, widget band stills.

## 2.0.1 / 2.0
- Original code-drawn Rayna menu-bar app.
