# Rayna for iPhone: App Store Connect metadata

| Field | Value |
|---|---|
| App name (≤30) | **Rayna – Water Reminder** (22) |
| Subtitle (≤30) | **Hydrate with a happy stingray** (29) |
| Bundle ID | `co.versantus.rayna.ios` (widget: `co.versantus.rayna.ios.widget`, App Group `group.co.versantus.raynawater`) |
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
Meet Rayna, the stingray who gets happier with every glass you drink. One tap to log, gentle nudges, a Home Screen widget, and a backflip when you hit your goal. 🌊

## Description
Rayna is a cheerful little stingray who lives in your water glass. The more you drink, the higher the water rises and the happier she gets. She starts the day a bit flat and droopy, and by the time you hit your goal she's flapping, smiling and doing a backflip in a burst of confetti.

LOG A GLASS IN ONE TAP
• Big “+1 glass” button with a satisfying haptic, a happy wiggle and a splash
• Made a mistake? Undo it
• Rayna's quips change as you go, from “Morning! I'm a bit… flat. Splash me?” to “GOAL! Backflip deployed.”

FRIENDLY REMINDERS THAT KNOW WHEN TO STOP
• Reminders every 30–120 minutes during your waking hours only
• Quiet hours, so nothing pings you at night
• Tap “Drank one 💧” right on the notification to log a glass without opening the app, or “Later” to snooze for 15 minutes
• Reminders stop once you've hit today's goal
• Optional evening nudge: “Fancy swapping the next pint for a pint of water?” 🍺➡️💧

HOME SCREEN WIDGET
• Small and medium widgets show Rayna and today's progress
• Tap “+1 glass” straight from the widget

BUILT FOR RUNNERS (AND EVERYONE ELSE)
• Default goal of 2.5 L, with a one-tap Run day toggle that adds 500 ml
• Set your own goal and glass size
• Streak dots show how many days in a row you've hit your goal

PRIVATE BY DESIGN
• No account, no tracking, no ads
• Everything stays on your iPhone

Rayna also lives in your Mac's menu bar. It's free and open source at rayna-water.netlify.app.

## Keywords (≤100, comma-separated, no spaces)
water,drink,hydration,reminder,tracker,habit,health,widget,stingray,running,glass,daily,goal,streak

## What's New (1.0)
Rayna's first splash on iPhone! 🌊

## App Review notes
No login is needed. Tap “+1 glass” to log water; the gear icon opens Settings. Reminders are local notifications (no server). The Home Screen widget's “+1 glass” button uses an App Intent. All data is stored on the device in an App Group shared with the widget.

## Age rating
Answer **None** to every content question (no violence, no mature themes, no gambling, no unrestricted web access, no user-generated content, no medical/treatment information). Result: **4+**. Rayna is general hydration encouragement, not medical advice.

## App Privacy (nutrition label)
**Data Not Collected.** Answer “No, we do not collect data from this app.” There are no third-party SDKs or analytics, and no tracking (no ATT prompt needed).

## Export compliance
`ITSAppUsesNonExemptEncryption = NO` is set in Info.plist, so there's no encryption question at upload.

## Screenshots
`appstore/screenshots/6.9/` (1320×2868, iPhone 17 Pro Max) and `appstore/screenshots/6.7/` (1290×2796, iPhone 15 Plus):
1. Over halfway, happy Rayna (60 %)
2. Early in the day, droopy Rayna (20 %)
3. Goal reached, 100 %
4. Settings (goal, glass size, reminders, quiet hours, evening pint-swap)

Regenerate: `cd iOS && scripts/screenshots.sh <sim-udid>:6.9 <sim-udid>:6.7` (after a simulator build).
iPad screenshots (13") are only needed if iPad stays enabled (`TARGETED_DEVICE_FAMILY = 1,2`). Otherwise set it to `1` for iPhone-only.
