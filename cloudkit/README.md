# CloudKit schema for pods (container iCloud.co.versantus.raynawater)

Record types: `Pod` (root, shared via CKShare), `Member`, `Nudge`, all in the owner's private custom zone `RaynaPod`.
The app reads the zone with `recordZoneChanges` (no queries), so no extra indexes are needed.

Pending invites, custom glass size and over-achiever badges do not add record types or fields.
Invites are `CKShare` participants. Custom size is the existing `glassML` integer inside the `RaynaPrefs` `payload` JSON.
Badges are raw strings inside the `RaynaProfile` `payload` JSON (`unlocks`). Pod-wide over-achievement compares existing `Member.ml` and `Member.goal`.

Development: the types are created automatically the first time a development build (Xcode Run) starts a pod.
Production (TestFlight/App Store) never auto-creates types. Deploy before testing pods in TestFlight:
- CloudKit Console → iCloud.co.versantus.raynawater → Schema → **Deploy Schema Changes…** → Production, or
- `xcrun cktool import-schema --team-id F9MJXEKGAR --container-id iCloud.co.versantus.raynawater --environment development --file cloudkit/schema.ckdb`
  (needs `xcrun cktool save-token`), then deploy to Production in the Console.
