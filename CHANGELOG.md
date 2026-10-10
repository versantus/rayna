# Changelog

All notable changes to Rayna (macOS menu-bar app + iOS app). macOS versions are listed; the iOS app ships as 1.0 (unreleased).

## Unreleased: 2.2.0

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
