# Rayna for iPhone: App Store Connect metadata

| Field | Value |
|---|---|
| App name (≤30) | **Rayna – Water Reminder** (22) |
| Subtitle (≤30) | **Hydrate with a happy stingray** (29) |
| Bundle ID | `co.versantus.raynawater.ios` (widget: `co.versantus.raynawater.ios.widget`, App Group `group.co.versantus.raynawater`) |
| SKU | `rayna-ios` |
| Version / build | 1.0 (1) |
| Primary category | Health & Fitness |
| Secondary category | Lifestyle (optional) |
| Price | Free |
| Support URL | https://rayna-water.netlify.app |
| Marketing URL | https://rayna-water.netlify.app |
| Privacy Policy URL | https://rayna-water.netlify.app/privacy.html |
| Copyright | © 2026 Versantus |

## Promotional text (≤170)
Meet Rayna, the stingray who gets happier with every glass you drink. One tap to log, gentle nudges, a Home Screen widget, and a happy spin when you hit your goal. 🌊

## Description
Rayna is a cheerful little stingray who lives in your water glass. The more you drink, the higher the water rises and the happier she gets. She starts the day a bit flat and droopy, and by the time you hit your goal she's flapping, smiling and spinning for joy in a burst of confetti.

LOG A GLASS IN ONE TAP
• Big “+1 glass” button with a satisfying haptic, a happy wiggle and a splash
• Made a mistake? Undo it
• Rayna's quips change as you go, from “Morning! I'm a bit… flat. Splash me?” to “GOAL! Happy spin deployed.”

FRIENDLY REMINDERS THAT KNOW WHEN TO STOP
• Reminders every 30–120 minutes during your waking hours only
• Quiet hours, so nothing pings you at night
• Tap “Drank one 💧” right on the notification to log a glass without opening the app, or “Later” to snooze for 15 minutes
• Reminders stop once you've hit today's goal
• Optional evening nudge: “Fancy swapping your next fizzy drink for a glass of water?” 🥤➡️💧

RAYNA GROWS WITH YOUR STREAK
• Unlock a bubble trail (3 days), a workout headband (7), a workout medal (14) and a baby ray buddy (30)
• A weekly recap with fun stats (“That's 22% of a bathtub”)
• Optional evening swap-a-fizzy-drink challenge with its own streak

HYDRATE WITH FRIENDS
• Start a pod over iCloud and invite friends with a link: no accounts
• See everyone's Rayna in a shared tank, send a friendly nudge (max 3 a day) and build a pod streak
• Share goal, streak and unlock cards to your story

WIDGETS, WATCH AND LIVE ACTIVITY
• Home Screen and Lock Screen widgets, with “+1 glass” right from the widget
• Apple Watch app and complications
• Optional exercise-day Live Activity on the Lock Screen and Dynamic Island

BUILT FOR HEAVY EXERCISE DAYS (AND EVERYONE ELSE)
• Default goal of 2.5 L, with a one-tap Exercise day toggle that adds 500 ml
• Optional Apple Health: workouts (including from Garmin or Strava via Health) switch on a heavy exercise day automatically, and glasses can be saved as Dietary Water
• Set your own goal and glass size
• Streak dots show how many days in a row you've hit your goal

PRIVATE BY DESIGN
• No account, no tracking, no ads
• Your data stays on your devices, in Apple Health (if you turn it on) and in iCloud for pods you join

Rayna also lives in your Mac's menu bar. It's free and open source at rayna-water.netlify.app.

## Keywords (≤100, comma-separated, no spaces)
water,drink,hydration,reminder,tracker,habit,health,widget,stingray,workout,watch,friends,goal,streak

## What's New (1.0)
Rayna's first splash on iPhone! 🌊

## App Review notes
No login is needed. Tap “+1 glass” to log water; the gear icon opens Settings. Reminders are local notifications (no server). The Home Screen widget's “+1 glass” button uses an App Intent. All data is stored on the device in an App Group shared with the widget. Optional features: Apple Health (Settings → Apple Health; reads today's workouts, writes Dietary Water), Pods (Settings → Friends → Pods; CloudKit sharing, needs iCloud sign-in, no developer server), Apple Watch app (WatchConnectivity), exercise-day Live Activity (Settings). Demo data for review isn't needed: one device can start a pod and see itself in the tank.

## Age rating
Answer **None** to every content question (no violence, no mature themes, no gambling, no unrestricted web access, no user-generated content, no medical/treatment information). Result: **4+**. Rayna is general hydration encouragement, not medical advice.

## App Privacy (nutrition label)
**Data Not Collected** (to confirm with Nik). There are no third-party SDKs or analytics, and no tracking (no ATT prompt needed). Health data stays in HealthKit on device. Pod data (display name and daily glasses/ml/goal/streak) lives in the users' own iCloud via CloudKit sharing, which the developer can't access. Apple treats that as not collected, but re-check this answer before submitting.

## Export compliance
`ITSAppUsesNonExemptEncryption = NO` is set in Info.plist, so there's no encryption question at upload.

## Screenshots
`appstore/screenshots/6.9/` (1320×2868, iPhone 17 Pro Max) and `appstore/screenshots/6.3/` (1206×2622, iPhone 17 Pro). Upload-ready flattened JPEGs: `appstore/upload-6.9/`, `appstore/upload-6.3/`:
1. Over halfway, happy Rayna (60 %)
2. Early in the day, droopy Rayna (20 %)
3. Goal reached, 100 %
4. Settings (Friends → Pods, goal, glass size, exercise-day Live Activity, reminders, fizzy-drink swap)
5. Rayna with unlocks (headband, medal, bubbles, baby ray), the "Your pod" card and the fizzy-drink swap card
6. Rayna's journey: weekly recap and the unlock collection
7. Pod: shared tank with friends, nudges and pod streak

Regenerate: `cd iOS && scripts/screenshots.sh <sim-udid>:6.9 <sim-udid>:6.3` (after a simulator build).
iPad screenshots (13") are only needed if iPad stays enabled (`TARGETED_DEVICE_FAMILY = 1,2`). Otherwise set it to `1` for iPhone-only.
