# Changelog

All notable changes to Rayna (macOS menu-bar app + iOS app). macOS versions are listed; the iOS app ships as 1.0 (unreleased).

## Unreleased
- Your own pod tile follows this device's log. It shows today's litres and percent, the same way as the main screen (`1.00 L · 31%`), and the tank fills as soon as you add or undo a glass. Each log, undo and new day writes `ml`, `goal` and `updated` on the existing Member record so the rest of the pod can see it. No new CloudKit fields.
- Pod screen shows pending CKShare invites as faded tiles (name or "Invited", "Waiting to join"). The owner can resend the share sheet or cancel the invite after a confirmation. No new CloudKit fields.
- Custom glass size: presets stay, and a typed size from 50 to 2,000 ml is saved in `glassML` (already synced on `RaynaPrefs`). +1 glass on iPhone, Mac and Watch uses it. The picker adds a Custom row; the millilitre field appears only while Custom is selected, and a saved size that is not a preset opens on Custom.
- Exercise day: the +500 ml boost is labelled "Exercise day (+500 ml)" (longer copy says "heavy exercise day"), with a dumbbell instead of a running figure. Badge names are Workout headband and Workout medal. Stored keys (`runDay`, `runBonusML`, `healthRunDay`, `healthAutoRun`, `liveActivityRunDay`) and unlock ids (`headband`, `medal`) are unchanged. Apple Health counts heavy-exercise workouts, not only runs. Fixes #6.
- Over-achiever badges: 125/150/200% of a day's goal, 3/7/30-day streaks of beating the goal, a personal-best day, and a pod-wide day where everyone beats their goal. Final art is in the iOS and Mac asset catalogs (`badge-<id>` and `badge-<id>-overlay`); SF Symbols remain only when an asset is missing. Drawing scripts live in `tools/badge-art/`. Debug builds can unlock them with `RAYNA_BADGES` or Settings → Unlock all badges.
- Mac menu bar matches the iPhone: same glass presets, pod screen, streak dots, reminder intervals, share-card preview, settings order and labels. Kid mode uses the same flag. No new CloudKit fields. Pod nudges stay fixed text. See the parity table in docs/V1.1-NOTES.md.
- iCloud sync uploads within a second of a log, and the other device picks it up from a silent push, from coming to the foreground, from opening the Mac menu, or within a minute if a push is missed. Merge rules are unchanged. See docs/V1.1-NOTES.md.

## Unreleased (iOS 1.0 build 3)
- Optional ocean sounds (Settings → Sounds, on by default): splash on +1 glass, bubbles on wiggle, harp glissando on the goal spin. Real recorded CC0 audio since build 5 (4 random splash variants, bubbles, harp-glissando goal chime by oggraphics since build 6; ~55 KB, credits in Sources/RaynaCore/Resources/Sounds/CREDITS.md). iOS uses the `.ambient` audio session, so sounds mix with other audio and obey the silent switch. Also on macOS.

## iOS 1.0 build 2
- Pods moved off the main screen into Settings → Friends → Pods. The main screen shows a compact "Your pod" card only when you're in a pod.
- No alcohol references: the swap-a-pint challenge is now the **swap-a-fizzy-drink** challenge (copy, notification, settings, metadata).

## 2.2.0: 2026-10-10

### Phase D
- **Apple Watch app (watchOS 10+):** big "+1 glass", progress ring, Rayna still by band, synced with the iPhone via WatchConnectivity (application context + messages/queued userInfo). Watch complication (circular/rectangular/corner/inline).
- **Run-day Live Activity (optional toggle):** Lock Screen + Dynamic Island progress with a +1 button. Starts when run day is on, ends at goal or when run day is turned off.

### Phase C
- **Pods (CloudKit sharing, container iCloud.co.versantus.raynawater):** "Start a pod" creates a zone + root record + CKShare (anyone with the link can join). Members publish daily glasses/ml/goal/streak. The shared tank shows everyone's Rayna at their own water level, with "Nudge 👋" (max 3 per person per day; delivered as a local notification after a silent CKDatabaseSubscription push) and a pod streak when everyone hits their goal. Works on iOS and macOS; on macOS it needs an iCloud-entitled signed build (the ad-hoc DMG shows a notice instead).

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
