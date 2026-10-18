# Halloween seasonal release — friendly vampire mobulas

Status: **plan only**. Do not implement from a side edit on `main`. This document is the spec for the work.

Baseline for every file path below: `cursor/pod-member-ray-appearance-3fc6` at `4e13c995` (PR #8, which contains PR #7). `main` (`0b9796f2`, iOS build 6) does not have skins, worn badges, Ray Facts, the quip catalogue, or the three iPhone layouts. Cut the implementation branch from PR #8 once that stack merges, or stack it on #8 if this has to move first. Merge order of the stack remains `v1.1` ← #3 ← #4 ← #5 ← #7 ← #8.

No CloudKit schema change. No in-app purchase. No App Store or TestFlight upload as part of this plan.

## Decision

Ship one reusable season gate, and one season: **Halloween**, a friendly mobula-ray costume. Mobulas' dark wings and cephalic fins already read as a cape and little horns, and they really do leap and glide. The costume is cute-spooky: a short cape, two friendly fangs, a soft moon in the water. No gore, no jump scares, no blood, no "mwah-ha-ha", no sudden flashes, no scary audio.

The costume is **on by default** for the whole window (adults and children; kid mode is still off). A Settings switch can turn it off while the window is open. When the window closes, the switch, the costume, the extra lines, the treats and the seasonal trophy all disappear. Nothing seasonal remains in the UI.

`RaynaSkin` cannot carry this. It is a colour cube over the turquoise body (`RaynaSkin.map` in `Sources/RaynaCore/RaynaSkin.swift`). Eyes, blush, smile and the cream rim stay as drawn. A cape and fangs are not body pixels. Do not add a `vampire` skin case, and do not change the user's saved `raynaSkin`.

## Season window

| | |
|---|---|
| Id | `halloween` |
| First day | **17 October**, local calendar, 00:00 |
| Last day | **1 November**, local calendar, inclusive |
| First off day | **2 November**, 00:00 local |
| Recurrence | Every year, same month and day |
| Time zone | The device calendar (`Calendar.current`), not a fixed UTC instant and not Europe/London |

17 October is the Friday before Halloween week. 1 November is the last day, which matches "mid-October through 1–2 November" and keeps 2 November ordinary. UK clocks go back on Sunday 25 October 2026. Use calendar components (month, day), not a `TimeInterval` from 17 October, so the extra hour does not shorten or lengthen the window.

The gate is pure and testable:

```text
SeasonGate.inWindow(now:calendar:) -> Bool
SeasonGate.isShowing(now:calendar:) -> Bool   // in window AND feature flag AND user has not opted out AND year is plausible
```

Year sanity, because there is no server clock: if `year < 2026` or `year > 2035`, `isShowing` is false. A device stuck in 1970 or 2001 must not grow a cape. A clock that is merely a few days wrong can still show or hide the theme. Say that in the Settings footer during the window. Do not phone home to correct it.

Kill switch, same pattern as `RaynaFeatures.kidMode` in `Sources/RaynaCore/RaynaExtras.swift`:

```text
RaynaFeatures.halloween = true   // set false to ship a rollback with the season compiled out
```

Debug only (never a user control): environment `RAYNA_SEASON=halloween` forces showing, `RAYNA_SEASON=off` forces hidden. Mirror the existing `RAYNA_BADGES` / `SIMCTL_CHILD_RAYNA_BADGES` pattern so screenshots and App Review can see the costume outside October.

### Manual off switch

Visible only while `inWindow && RaynaFeatures.halloween`. Do not insert the row and hide it; omit the section so VoiceOver and the Mac window have nothing to land on off-season.

| | |
|---|---|
| Copy | **Halloween costume** |
| Control | Toggle, default **on** |
| Footer | "A friendly cape for Rayna until 1 November. Turn it off if you'd rather the usual ocean. It puts itself away on 2 November." |
| Storage | Bool `halloweenOff` in the App Group defaults. **Missing means on.** Same rule as `exerciseExtraOn`: do not upload a missing key as off. |
| Sync | Add `halloweenOff` to `SyncLocalDefaults.boolSettings` in `Sources/RaynaCore/RaynaCloudSync.swift`. Last writer wins, inside the existing `RaynaPrefs` payload. No new CloudKit field. |
| Off-season | `isShowing` ignores the key for rendering. The key may stay in defaults. The row comes back next 17 October on whatever value they last set. |

Places to add the row, and nowhere else:

- iPhone: `iOS/Rayna/SettingsView.swift`, inside the existing **Appearance** section (the Layout picker), above the footer.
- Mac: `Sources/Rayna/ContentView.swift`, in the Settings column next to the other Appearance rows (the Mac has no layout picker; add the toggle as its own row in that settings stack).
- Not on the Watch. The phone tells the Watch whether to decorate (below).
- Not on the menu-bar panel. Settings is the one switch.

No prompt, banner, or "want Halloween?" alert when the window opens. The costume is simply there.

### What `isShowing == false` must guarantee

- Speech uses the normal quip pool only.
- Facts use `RayFacts.all` only.
- No treat animation and no seasonal sound.
- No costume overlay on iPhone, iPad, Mac, Watch, pod tile, share card, or celebration.
- The trophy grid does not list the seasonal stamp.
- Settings has no Halloween row.
- Widgets, the Watch complication, the menu-bar glyph, and the app icon were never seasonal, so they do not need a second path.

## Framework (keep it small)

New file `Sources/RaynaCore/SeasonGate.swift`. One struct, one registered season. A later season (winter, World Ocean Day) adds a value to the enum and its own copy and art. It does not get its own prefs system.

```text
enum SeasonID: String { case halloween }

struct SeasonWindow {
    var id: SeasonID
    var startMonth, startDay, endMonth, endDay: Int   // inclusive, local
    var offKey: String                                 // "halloweenOff"
}

enum SeasonGate {
    static let halloween = SeasonWindow(id: .halloween, startMonth: 10, startDay: 17, endMonth: 11, endDay: 1, offKey: "halloweenOff")
    static func inWindow(_ s: SeasonWindow, now: Date, calendar: Calendar) -> Bool
    static func isShowing(_ s: SeasonWindow = .halloween, now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults, force: SeasonForce = .none) -> Bool
}
```

Do not build a content pipeline, a remote config, or a season calendar UI. Halloween's lines, facts, sounds and art stay in named types next to the existing ones (`QuipLines`, `RayFacts`, `RaynaSounds`). The gate is the only shared mechanism.

`inWindow` for a window that does not cross the new year (this one) is: month/day ≥ start and month/day ≤ end. Write it so a future window that crosses 1 January (a winter season) can set `endMonth < startMonth` and still work. Test both shapes even though only Halloween ships.

## Costume (the "seasonal skin")

Drawn in a new `SeasonCostume` view, overlaid in the same place `AnimatedRayna` already overlays `RaynaAccessories` (`Sources/RaynaCore/AnimatedRayna.swift`). It is **not** a `RaynaUnlock`, so it never enters `wornSet` and never takes a head, chest, fin or scene slot.

Placement uses the existing head pose from `RaynaAnchors` (`Sources/RaynaCore/RaynaAnchors.swift`, JSON under `Sources/RaynaCore/Resources/RaynaFrames/anchors/`). The head pose is unit coordinates plus rotation and opacity, and it already fades out when she swims side-on. Pin the cape and the fangs to that pose with a fixed offset (fangs a little below the head point, cape across the top of the wings). Do not add a mouth anchor and do not re-run `tools/rayna-frames/track.py` for this release. Opacity of the costume follows the head pose so a side-on swim does not leave a floating cape.

The user's colour still comes from `SkinPainter` / the Watch still `band<n>-<skin>`. A turquoise ray in a cape is correct. Do not switch them to Midnight.

Reduce Motion and the Watch always-on state (`isLuminanceReduced` on `WatchHome`) show the costume as a still. No flapping, no bobbing bats.

VoiceOver on the ray, in addition to the existing percent label: "Rayna in a friendly Halloween cape." The wearing strip on the Badges screen (`wearingStrip` in `Sources/RaynaCore/RaynaAccessories.swift`) keeps saying which badges are worn. The cape is not one of them, so do not add it to "Ray is wearing" and do not draw `WearRibbon` for it.

### Pod tiles

PR #8 paints each other member from `Member.raynaSkin` and `Member.wornSet` (`PodAppearance` in `Sources/RaynaCore/PodInvites.swift`). An unknown skin string falls back to classic. Your own tile uses the local still (`PodLive`).

- Your tile: draw `SeasonCostume` when `isShowing`, because it uses the local ray. No record write.
- Everyone else's tile: **no costume** this release. Adding it means a new `Member` string and a Production schema deploy (the 16 Oct 2026 miss is why that bar is high). See open questions.
- Publishing `wornSet` does not change. Do not stash a costume bit in the mask. `WornSet.badges(from:)` only keeps bits that match `RaynaUnlock.allCases`, and the tests require new cases to be appended, never inserted. A private bit would be stripped on the next wear change.

## Speech

The speech bubble is the quip, not a separate screen.

- iPhone: `quipBubble` / `plainQuipBubble` in `iOS/Rayna/ContentView.swift` (layouts in `iOS/Rayna/MainScreen.swift` share it).
- Mac menu bar: the quip in `Sources/Rayna/ContentView.swift`.
- The line is chosen by `QuipPicker.statusLine` → `QuipCatalog.pool` (`Sources/RaynaCore/RaynaQuips.swift`) from categories in `Sources/RaynaCore/QuipLines.swift`.

Add a category `halloween` with **no** `from` progress, 20 lines, every line `kidSafe: true`. British spelling. First person, the way Rayna already speaks. Warm and silly. Allowed images: cape, fangs that don't bite, pumpkin, moon, bats that are tiny and friendly, mobulas leaping, treats. Banned, and covered by the existing banned-word test in `testQuipCatalogCountsBannedWordsAndShuffle`: blood, gore, death, kill, scary, fright, scream, trick, haunt, zombie, skeleton, devil-as-a-threat, mwah, laugh-as-a-villain, countdown language ("only N days", "last chance", "before it's gone"). Also keep the catalogue's existing bans (alcohol, shame, diets, medical claims).

Do **not** replace the progress band. `QuipCatalog.pool` already appends the kid list onto an in-progress band. Do the same: when `SeasonGate.isShowing`, append the halloween lines to the current band's pool, then let the shuffle bag run. Hydration lines stay in the mix. A redraw with the same salt still returns the cached line (`QuipPicker`'s cache key). Include `isShowing` in that cache key so the first glass inside the window, and the first redraw after 2 November, cannot keep a stale seasonal line.

Reminders stay on the `reminder` list only. `QuipPicker.nextReminder` feeds notifications, and `ReminderScheduler` schedules about 48 hours ahead. A Halloween line queued on 1 November would arrive on 2 November. The nudge window (`Sources/Rayna/NudgeController.swift`) uses those reminder lines too. Leave both alone.

Goal lines stay the goal list. Hitting the goal can still say "Happy spin deployed." The halloween lines are in the pool only for in-progress bands (`start` through `almost`), matching how kid lines are added.

## Ray Facts

Facts already surface in the speech bubble at 25 / 50 / 75 / 100 percent (`RaynaExtras.factForMilestone` in `Sources/RaynaCore/RaynaExtras.swift`). The bubble shows `RayFactTag` ("🔍 Ray fact") and tapping opens `RayFactPage`. Same on the Mac (`bubbleFact` / `factPage` in `Sources/Rayna/AppState.swift` and `Sources/Rayna/ContentView.swift`). The toggle is Settings → Ray Facts (`rayFactsOn`), synced in `boolSettings`.

Halloween facts are a **second list**, `RayFacts.halloween`, not extra rows in `RayFacts.all`. `factsUnlocked` is an index into `all` and is merged with `max` in `RaynaSyncLedger`. Inserting seasonal rows into `all` would skip permanent facts or repeat them. Do not do that.

While `isShowing` and `rayFactsOn`:

- `factForMilestone` still fires once per newly crossed quarter.
- It prefers the next unshown Halloween fact.
- It does **not** increment `factsUnlocked`.
- Shown Halloween facts are a count, `halloweenFactsShown`, stored as an int and merged with **max** the same way as `factsUnlocked` (add the field on `SyncLocalSnapshot` / the profile payload, next to `factsUnlocked` in `Sources/RaynaCore/RaynaSyncLedger.swift`). A last-writer-wins int would let an older device rewind the count.
- When the Halloween list is exhausted, the quarter falls through to today's `unlockNextFact()` behaviour.
- The tag stays "🔍 Ray fact". The page title uses the kind name ("Devil ray"), not a second visual system.
- Off-season, `factForMilestone` never reads the Halloween list. The count may remain so next year does not repeat the eight lines from the start. That count is not shown anywhere.

Draft lines, all child-friendly. **Do not ship one until it has a source key in `docs/RAY-FACTS-SOURCES.md`**, same rule as the current 41 facts. The catalogue already has one mobula leap fact (`NatGeo-mobula`); do not duplicate it.

| Kind | Draft line | Needs a source |
|---|---|---|
| devil | Mobula rays are sometimes called devil rays. The little "horns" are fins beside the mouth, and they help scoop up food. | cephalic fins |
| devil | Some mobula rays leap out of the water and glide for a moment, almost like flying, then splash back down. | jumping / flying |
| devil | Mobula rays eat tiny plankton. They are not hunting anyone. | diet |
| devil | Mobula rays don't have a stinging barb on the tail. | no barb |
| devil | A mobula's mouth is at the front of its head, so it can swim along and scoop dinner as it goes. | mouth position |
| devil | Mobulas like company. They are often seen swimming in groups. | schooling |
| devil | Their wide dark wings are what make a Halloween cape feel so right. They are still gentle. | wingspan / colour, keep the tone |
| devil | A baby mobula is born able to swim. It does not hatch from a mermaid's purse the way a skate does. | live birth |

`RayGlyph` already draws cephalic lobes for `.devil` and `.manta`. Reuse that glyph. No new illustration.

## Trick or treat

The user-facing word is **Treat**. The word "trick" does not appear in copy, VoiceOver, or notifications. Logging water never removes progress, never shortens a streak, and never hides a badge. There is no random outcome that can be empty, and nothing to buy.

Two kinds, both guaranteed when they fire:

1. **Big treat.** The existing quarter-goal fact (above). At most four a day, because `factForMilestone` already records how many quarters have fired today (`factMilestone` / `factMilestoneDay`). During the season the fact is a Halloween one until that list runs out. This is the surprise.
2. **Little treat.** Any other +1 glass while `isShowing`, up to **6 a day**. Feedback is one of three short beats, drawn from a shuffle bag (the same shape as `QuipShuffleBag`, so the same beat is not repeated twice in a row, and the bag never returns "nothing"): cape flutter, sparkle, or a soft pop. After 6, the glass is an ordinary glass: splash, wiggle, no extra beat, and **no message** that a treat was missed.

Caps are per local day key (`RaynaCopy.dayKey`). Store `treatDay` and `treatCount` in defaults. They are device-local. Do not sync them. A second device may also play a little treat; that is fine and is not a prize.

Rules:

- Fires on +1 glass from the iPhone (`iOS/Rayna/AppModel.swift`, next to the existing `RaynaSounds.shared.play(.splash)`), the Mac (`Sources/Rayna/AppState.swift`), and when a Watch glass lands on the phone (`iOS/Rayna/WatchSync.swift`). The Watch itself does not play the treat.
- The swap-a-fizzy action logs a glass, so it counts as one glass. It does not get a second treat.
- Undo does not play a treat, does not decrement `treatCount` (undo-then-add cannot farm past the cap), and does not revoke the seasonal stamp. If a fact card is on screen, undo dismisses it. Do not rewind `halloweenFactsShown` (they already saw it). If undo drops progress under the quarter that just fired, set `factMilestone` back so the next crossing that day can show a fact again; that path already knows the Halloween list position and will not repeat a consumed fact.
- Widget and notification "Drank one" actions can log while the app is backgrounded. Do not present a card from there. If a big-treat quarter was crossed, the next time the app is open it may show that fact if the quarter is still crossed and the card was never shown (one pending flag, `treatPendingFact`). Never a queue of modals.
- Reduce Motion: little treat is the sound plus a still sparkle (or nothing moving). The fact card still appears; it is text.
- Sounds off (`soundsOn`, default on, Settings → Sounds): the visual still happens, the new sounds do not. The existing splash and chime already obey this switch. Little treats use it too.
- No treat on merely opening the app, on a nudge, or on a reminder.

Copy for the little-treat moment is one short line in the speech bubble, from an 8-line bag in `SeasonCopy`, held until the next glass or band change, then the normal picker resumes. Examples: "A treat. Cape's on, and so is the next sip." Never "trick", never a countdown.

## Seasonal stamp (trophy)

One stamp, so the trophy screen has a seasonal moment without touching wear rules.

| | |
|---|---|
| Id | `moonleap` |
| Title | Moonleap |
| Earned | The first day in the window that `ml >= goal` (meeting the goal counts; this is not an over-achiever badge) |
| Stored | The raw string `moonleap` inside the existing `unlocks` array on the profile. Union merge already keeps strings it does not know. Append-only: do not insert it in the middle of `RaynaUnlock.allCases` if it becomes a case. |
| Worn | **No.** It has no slot, no `WearRibbon`, no shirt icon, and it is not written into `wornSet`. |
| Why not worn | Head, chest and fin each hold one badge (`BadgeSlot`, `WornSet.normalized`). A cape badge on the head would swap off the workout headband or the 30-day crown. Taking it off on 2 November would either wipe that bit or leave the head slot empty. The costume overlay avoids both. |
| UI | A card on the Badges / Journey grid only while `isShowing` and the id is unlocked. Reuse the card layout in `RaynaAccessories.swift` but do not call `WearRibbon` and do not offer a wear toggle. Locked hint while the season is showing and it is not yet earned: "Hit your goal on a day in Halloween week." No dates that create pressure, no "or it disappears forever". |
| Off-season | The getter that feeds the grid filters it out, the same way `RaynaExtras.unlocked` already hides premium cases when `RaynaFeatures.scenePack` is off. The string stays in `unlocks` so next October the card is back without earning it again. |
| Celebration | The existing unlock celebration card, once, the day it is earned. Confetti uses the seasonal palette (indigo, amber, pink) instead of a new animation. Share card (`RaynaShareCard`) may show the costume overlay that day; it does not show a countdown. |
| Auto-wear | Not applicable. `WornSet.autoWear` is unchanged. |

If the stamp is modelled as a `RaynaUnlock` case it **must be appended after `turtles`**, because `wornSet` bits are `allCases` positions (`testWearUpToThreeBadges` documents this). Prefer a side list `SeasonStamp` that is not a `RaynaUnlock`, so a future badge can still be appended without a seasonal hole in the mask. The profile `unlocks` array can hold the extra raw string either way; the grid filter is what hides it.

Pod wave, nudges and the shared tank are unchanged.

## Watch

`iOS/RaynaWatch/RaynaWatchApp.swift` draws `WatchSea` plus a pre-coloured still (`band<n>` or `band<n>-<skin>`). The Watch target does not link RaynaCore. `iOS/RaynaWatch/RaynaStage.swift` is a copy of the sizing rule. Keep that split.

- `WatchKeys` (`iOS/WatchShared/WatchShared.swift`) gains `season`. The phone writes `"halloween"` or `""` in the same application context that already sends `skin` and `scene` (`iOS/Rayna/WatchSync.swift`). An older Watch build ignores unknown keys (`WatchModel.apply` only reads keys it knows).
- `WatchSea`: while the flag is set and the watch is awake, tint the top of the gradient toward night indigo and draw one soft moon circle in the existing Canvas. No bats. `still == true` (always-on, `isLuminanceReduced`) freezes the moon where the still path already freezes waves.
- The ray still stays `model.band(...)` for the **real** skin. Do not send `skin=halloween`. There is no `bandN-halloween` imageset, and inventing one would fork seven colours times five bands.
- A single small cape PNG may sit on the still, positioned by eye (the Watch has no `RaynaAnchors`). If the asset is missing, the moon tint alone is acceptable.
- Complication (`iOS/RaynaWatchWidget/RaynaWatchWidget.swift`): **no theme**. Circular, rectangular, corner and inline stay as they are. A complication cannot host a scene, and a seasonal still would sit on the watch face after 1 November until the next push.

## Sounds

Existing player: `Sources/RaynaCore/RaynaSounds.swift`. Cases today: `splash` (four variants), `bubbles`, `chime`. Files are AAC `.m4a` in `Sources/RaynaCore/Resources/Sounds/`. The whole set is about 55 KB (`chime.m4a` is 23.9 KB, splashes 6–9 KB, bubbles 5.9 KB). iOS sets `AVAudioSession` category `.ambient` with `.mixWithOthers`, so the Ring/Silent switch mutes them and they mix with music. The `soundsOn` default is true. macOS uses `AVAudioPlayer` with no session (there is no silent switch). The Watch does not play these.

Add three cases, used only by little treats, and only through `RaynaSounds.play` so the switch and the silent switch apply:

| File | Moment | Length | Size target |
|---|---|---|---|
| `flutter.m4a` | Cape flutter | ≤ 0.4 s | ≤ 8 KB |
| `pop.m4a` | Soft pop | ≤ 0.3 s | ≤ 8 KB |
| `sparkle.m4a` | Short bright chime, no laugh | ≤ 0.6 s | ≤ 12 KB |

Mono AAC, a short fade in and out, loudness around −16 LUFS, matching `CREDITS.md`. Seasonal total under 30 KB.

Source: **original audio owned by Versantus**, generated or recorded for Rayna, noted in `CREDITS.md` as original. Do not pull a horror pack, a laugh, or a CC-BY track that needs a credit line in the binary. Do not use the existing harp `chime.m4a` as the sparkle; the goal chime should stay special.

No seasonal sound on notifications, widgets, Live Activity, or the Watch.

## Art

Overlays, not a new Higgsfield frame set. Regenerating `idle-happy`, `idle-thirsty`, `wiggle`, `swim-in`, `swim-off`, `pout-swim-off` and the five bands times seven colours would fork the skin pipeline and the Watch stills. The colour cube and the anchors already track the clips.

Canvas is the ray frame: **256×256 PNG with alpha**, the size the clips use. Ship an imageset in both catalogues that already hold badge art: `iOS/Rayna/Assets.xcassets` and `iOS/RaynaMac/Assets.xcassets`. The `./build.sh` menu-bar binary has no asset catalogue (PR #7); seasonal images there fall back to nothing, and the Mac App Store target `RaynaMac` is the one that shows them. Watch assets go in `iOS/RaynaWatch/Assets.xcassets` only if the cape PNG is included.

| Asset | Where it is used | Notes |
|---|---|---|
| `costume-cape` | Overlay on the head pose, iPhone, iPad, Mac, own pod tile, celebration, share card | Short rounded cape, indigo with a pink lining. No skull clasp. Transparent outside the cloth. |
| `costume-fangs` | Same overlay, offset below the head pose | Two small white triangles. Friendly, not dripping. |
| `costume-horns` | Optional, same overlay | Two short curved fins, echoing cephalic lobes. Skip if they crowd the eyes. |
| `stamp-moonleap` | Trophy card only | A mobula mid-leap in front of a moon, square, readable at ~80 pt. |
| `cape-watch` | Optional, Watch app only | One PNG, about 100 px, pinned to the still. |
| Moon | Watch and, if wanted, the iPhone immersive sky | **Drawn in code** (circle, soft glow). No bitmap. |
| Bats | Little-treat flutter only | One tiny bat PNG, or a 4-frame loop, max 128 px. Reduce Motion shows a single frame. No bat in the resting scene. |
| Sparkle | Little treat | Recolour the existing confetti. No new asset. |
| App icon, menu-bar glyph, widget bands | Unchanged | A seasonal icon needs a separate binary marketing pass and would still be installed in December. |

Palette, kept inside Rayna's existing colours (`docs` brand notes and `RaynaBrand`): night indigo for the cape, aqua for the moon edge, pink `#FF8FB0` for the lining and cheeks, amber only as a small pumpkin accent. Do not introduce Versantus agency colours. Text on the immersive layout stays the current ink / white-on-sea pairing; a darker sky must still clear the white litre labels on the Watch (they already sit on `#083359`-family water with a shadow).

Badge imagesets today are `badge-<id>` (composite) and `badge-<id>-overlay` (art alone). The stamp is not worn, so it does not need an overlay imageset. One `stamp-moonleap` imageset is enough. If the asset is missing, the card uses the SF Symbol `moon.stars.fill`, which the jellies scene already uses as a fallback.

## Surfaces

| Surface | In season | Off season |
|---|---|---|
| iPhone main screen (Immersive, Hero, Balanced) and iPad column | Costume on the ray, mixed quips, fact card, little treats | Identical to today |
| Mac menu-bar popover | Same costume and quips, via shared `AnimatedRayna` | Identical to today |
| Mac nudge window | Unchanged reminder lines | Unchanged |
| Watch app `WatchHome` | Moon tint, optional cape, real skin still | Today's sea |
| Watch complication | Unchanged | Unchanged |
| iPhone widgets, Lock Screen, Live Activity | Unchanged | Unchanged |
| Pod tank | Costume on **your** tile only | Unchanged |
| Badges / Journey | Moonleap card if earned | Card absent |
| Settings | One toggle in Appearance | Row absent |
| Share card | Costume if showing that day | Unchanged |
| Menu-bar glyph and app icons | Unchanged | Unchanged |

## Accessibility

- **Contrast.** Costume art sits on the ray, not under the litre text. Do not darken the Hero card's text area. Watch litres stay white with the existing shadow. The moon is decoration and `accessibilityHidden`.
- **Reduce Motion.** `AnimatedRayna`, `WatchSea`, confetti and `RayVisitorsLayer` already read `accessibilityReduceMotion`. The costume uses the still pose. Little treats do not flap. Fact card uses the existing opacity transition only; skip the scale when Reduce Motion is on (the bubble currently uses `.opacity` combined with `.scale`).
- **VoiceOver.** Ray label gains the cape phrase only while showing. Fact label stays "Ray fact: …". The Settings toggle is "Halloween costume" with the footer as the hint. The stamp card value is "Earned" or "Not earned yet", never "Worn". Treat beats are not separate buttons. `WearRibbon` stays `accessibilityHidden`; the seasonal card does not use it.
- **Dynamic Type.** No new text below `.footnote`. The fact page already scrolls. Halloween lines obey the bubble's existing 3-line limit (unlimited at accessibility sizes).
- **Haptics.** Do not add a custom haptic. The system button click on +1 glass is enough. No buzz that reads as a scare.

## Localisation

The app has no String Catalog and no `NSLocalizedString`. Copy is English literals in Swift. This release stays that way. Put every new user-facing string in `Sources/RaynaCore/SeasonCopy.swift` so a later catalogue has one file to wrap. British spelling ("favourite" is not needed; use "colour" only if a string says it). Do not localise the eight fact drafts until the source pass is done.

## App Store

Age rating stays **4+**, every content question **None**, including Horror/Fear (`appstore/metadata.md`). The costume is a cartoon cape, not a horror theme. Do not opt the app into the Made for Kids category as part of this work. Do not add an in-app purchase; the scene-and-colour pack stays behind `RaynaFeatures.scenePack` / Labs and is not part of Halloween.

Copy rules for the listing, What's New, and review notes:

- Describe "a friendly Halloween costume", not a scary vampire.
- No countdown, no "limited time" pressure, no "don't miss", no implication that a streak or badge is lost if you skip a day. The stamp hides off-season and returns next year; the listing does not need to mention that.
- Do not replace the year-round screenshots in `appstore/screenshots/`. A reviewer looking in July, or a shopper in July next year, should see the ocean. Seasonal screenshots are optional and only if a version is submitted during the window.
- Review notes should mention `RAYNA_SEASON=halloween` so review can see the costume whenever they open the build. Also say the theme turns itself off on 2 November and that there is nothing to buy.
- What's New can mention the costume in the build that introduces it, worded so a review that slips past 1 November is still true: the costume appears in the last two weeks of October and on 1 November.
- Privacy label unchanged. No new data, no new SDK.
- `ITSAppUsesNonExemptEncryption` stays NO.

A build submitted in September is safe: the gate is closed, the assets are inert. A build submitted after 1 November 2026 is also safe: it waits until 17 October 2027 unless someone runs it with the debug environment.

## Rollback

There is no remote config. Rollback is a build.

1. `RaynaFeatures.halloween = false` hides the season even inside the window. Ship that if the costume or the treats misbehave.
2. The date gate means a bad build still goes quiet on 2 November without a release.
3. No schema deploy, so there is nothing to roll back in CloudKit.
4. `halloweenOff` left in prefs is harmless when the flag is false.
5. Do not delete `moonleap` from users' `unlocks` arrays in a migration. Hiding it is the rollback. Deleting it would make next year re-earn, and a bad migration is worse than a dormant string.

## Testing

Unit tests in `Tests/RaynaCoreTests/FeatureTests.swift` (or a new `SeasonTests.swift` in that target). `swift test` from the repo root. No Xcode in the plan-writing environment; the implementation branch runs these on a Mac.

Gate:

- 16 October, any year 2026–2035: hidden. 17 October 00:00: showing. 1 November 23:00: showing. 2 November 00:00: hidden.
- A calendar in `Pacific/Auckland` and one in `America/Los_Angeles` on the UTC instant that is still 16 October in London and already 17 October locally: local calendar wins.
- 25 October 2026, Europe/London, across the DST change: still showing.
- Year 1970 and year 2040, month October: hidden.
- `halloweenOff == true` inside the window: hidden. Missing key: showing.
- Flag `halloween = false`: hidden even on 31 October with the key absent.
- `RAYNA_SEASON` force values override the clock in debug and do not exist as a stored user pref.

Costume and sync:

- Toggling the costume does not change `wornSet` bits, `raynaSkin`, or `unlocks` other than the optional `moonleap` string.
- An unknown skin string still resolves to classic (existing PR #8 test). Halloween must not write a new skin string.
- `moonleap` in the middle of `RaynaUnlock.allCases` is a failing test if someone inserts it. If it is a case, the test asserts it is the last case.
- Profile union keeps `moonleap` from the other device and does not drop unknown unlock strings.
- Grid filter: stamp present on 31 October if unlocked, absent on 2 November, present again on 17 October the next year without a new earn.

Speech and facts:

- Halloween lines are `kidSafe` and contain none of the banned words.
- Reminder pool and exercise pool do not gain halloween lines.
- In-progress pool contains both the band lines and the halloween lines while showing, and only the band lines when hidden.
- Cache key changes when the gate flips, so a line chosen on 1 November is not reused on 2 November for the same salt.
- Crossing 25% while showing does not increment `factsUnlocked` when a Halloween fact is returned. The next ordinary fact index is unchanged.
- `halloweenFactsShown` merges with max.
- With Ray Facts off, no fact card and no Halloween fact.

Treats:

- Glasses 1–6 in a day each return a little treat; glass 7 returns none; none of the six results are empty.
- The shuffle bag does not repeat the same beat twice in a row when more than one beat exists.
- Undo does not increment or decrement `treatCount`.
- A quarter crossing returns a big treat even when the little-treat cap is already spent (the fact is independent).
- After the Halloween fact list is exhausted, a quarter uses `RayFacts.all`.

UI pass on a Mac (implementation, not this plan): iPhone SE and a Pro Max, light and dark, large Dynamic Type, Reduce Motion, VoiceOver on the bubble, the toggle and the stamp card; Mac popover; Watch simulator awake and always-on; 16 October vs 31 October vs 2 November via the debug environment. Confirm the Settings row is absent off-season by VoiceOver rotor, not only by eye.

## Task breakdown

Sizes are relative (how much code and art), not a schedule. S is one type plus tests. M is a feature across the shared package and one or two apps. L is the art set.

| Step | Size | Depends on | Done when |
|---|---|---|---|
| 1. `SeasonGate` + year, DST, time zone, force, and opt-out tests | S | Nothing | Tests above for the gate pass |
| 2. `halloweenOff` in defaults and `boolSettings`, missing means on | S | 1 | Sync round-trip test; no upload when the key was never set |
| 3. Settings row on iPhone and Mac, omitted off-season | S | 1, 2 | VoiceOver label; row absent on 2 November |
| 4. `SeasonCopy` + 20 halloween quip lines, pool append, cache key | M | 1 | Banned-word test; reminders unchanged |
| 5. Halloween fact list, source keys, `factForMilestone` branch, max-merge count | M | 1 | `factsUnlocked` unchanged by a seasonal fact |
| 6. Little-treat bag, daily cap, undo rules, pending fact flag | M | 1, 5 | Cap and undo tests |
| 7. Three m4a files, `RaynaSound` cases, `CREDITS.md` | S | 6 | Plays only via `RaynaSounds` when `soundsOn`; silent switch still ambient on iOS |
| 8. `SeasonCostume` overlay on `AnimatedRayna`, head-pose pin, Reduce Motion, VoiceOver | M | Art of the cape and fangs | Own pod tile shows it; `wornSet` test still passes |
| 9. Moonleap stamp, grid filter, one celebration, no wear control | M | 1 | Hidden off-season; not in `wornSet` |
| 10. Watch moon tint, `WatchKeys.season`, complication untouched | M | 1 | Old payload without `season` still loads; complication snapshot has no cape |
| 11. Art pass | L | Can start immediately | Assets in the table, both iOS and RaynaMac catalogues |
| 12. Notes in `docs/V1.1-NOTES.md`, `CHANGELOG.md`, and a short App Review paragraph in `appstore/metadata.md` | S | 1–10 | Review notes mention `RAYNA_SEASON` |

Steps 4, 5, 6, 8, 9 and 10 can proceed in parallel after the gate exists. Art (11) blocks a polished step 8 but not the gate. Do not start a widget theme, an icon theme, or a `Member` schema field inside this breakdown.

## Files to touch (implementation)

New:

- `Sources/RaynaCore/SeasonGate.swift`
- `Sources/RaynaCore/SeasonCopy.swift`
- `Sources/RaynaCore/SeasonCostume.swift` (view)
- Sound files and imagesets named above
- Tests in `Tests/RaynaCoreTests/`

Edit:

- `Sources/RaynaCore/RaynaQuips.swift` — append halloween lines in `pool`, include the gate in the picker cache key
- `Sources/RaynaCore/QuipLines.swift` — the category
- `Sources/RaynaCore/RayFacts.swift` — `halloween` list only
- `Sources/RaynaCore/RaynaExtras.swift` — `factForMilestone`, stamp filter, `RaynaFeatures.halloween`
- `Sources/RaynaCore/RaynaSounds.swift` — three cases
- `Sources/RaynaCore/RaynaCloudSync.swift` — `halloweenOff` in `boolSettings`
- `Sources/RaynaCore/RaynaSyncLedger.swift` — `halloweenFactsShown` max-merge
- `Sources/RaynaCore/AnimatedRayna.swift` — overlay the costume
- `Sources/RaynaCore/RaynaAccessories.swift` — stamp card, no ribbon
- `Sources/RaynaCore/Resources/Sounds/CREDITS.md`
- `iOS/Rayna/SettingsView.swift` — toggle
- `iOS/Rayna/AppModel.swift` — treat on +1 glass
- `iOS/Rayna/WatchSync.swift` — send `season`
- `iOS/WatchShared/WatchShared.swift` — key
- `iOS/RaynaWatch/RaynaWatchApp.swift` — moon tint
- `Sources/Rayna/AppState.swift` and `Sources/Rayna/ContentView.swift` — Mac parity
- `docs/RAY-FACTS-SOURCES.md`, `docs/V1.1-NOTES.md`, `CHANGELOG.md`, `appstore/metadata.md`

Leave alone: `RaynaSkin.swift`, `BadgeWear.swift` (unless a test needs a one-line assertion that seasonal wear is not a slot), `PodService.swift` record fields, `cloudkit/schema.ckdb`, widget and complication views, `ReminderScheduler.swift`.

## Open questions for Nik

1. **Window.** 17 October through 1 November inclusive, device-local, repeating every year. Is 1 November the last day you want, or should 2 November stay dressed as well?
2. **2026 versus next year.** The open stack (#3 through #8) is not merged, and iOS 1.1 is not submitted. A build that misses 1 November 2026 simply waits until 17 October 2027. Is a 2026 TestFlight during the window required, or is "ready for next October, previewable with `RAYNA_SEASON`" enough?
3. **Stamp versus a worn cape badge.** This plan keeps the cape as an overlay so it cannot knock the workout headband or the crown off the head slot. The trophy card is a Moonleap stamp with no shirt sash. Do you want it wearable anyway?
4. **Other people in the pod.** Their tiles stay their real colour and badges. Showing their capes needs a new `Member` field and a Production schema deploy. Leave that out?
5. **Who it dresses.** Everyone, including while kid mode is still flag-off. Confirm you do not want it limited to a future kid-mode switch.
6. **Speech mix.** Halloween lines are added into the current progress pool, not a full replacement, and they never go out in reminders. Is a stronger costume voice (halloween lines only, until the goal) what you actually want on the bubble?
7. **Art path.** Overlays on the current frames, not a new Higgsfield clip set. Confirm you do not want a fully repainted vampire mobula.
8. **Name in the lines.** The UI title is "Rayna". The Badges strip says "Ray is wearing". Halloween lines should say Rayna, unless you want Ray.
9. **Sounds.** Original short AAC, owned by Versantus, under 30 KB. If you already have a sound source in mind, say so before step 7; otherwise the implementation generates and credits originals.
10. **English only.** No String Catalog this release. Say if a translation pass has to be in the same build.
