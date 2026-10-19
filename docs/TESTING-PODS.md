# Testing pods with two people

Use this when a pod change needs a second iCloud account. Sample members in a Debug build are only for layout. They never become CloudKit records.

## Accounts

- One side is Nik's iPhone, iPad or Mac, signed into Nik's iCloud account.
- The other side is a second iCloud account. That can be the iOS Simulator, a spare device, or Sophie's phone.
- Sign Rayna into iCloud on both. The container is `iCloud.co.versantus.raynawater`.

## Same CloudKit environment

Xcode **Run** (a Debug build) uses the **Development** environment. **TestFlight** and the **App Store** use **Production**.

A pod created on one environment is invisible on the other. Do not invite a TestFlight install from an Xcode build, or the other way round. Both devices need builds pointed at the same environment.

Development creates the pod record types the first time a development build starts a pod. Production does not. If Production has not had the schema deployed, start with two Development builds.

## Invite, accept, drink, leave

1. On Apple ID A, open **Settings → Pod** (iPhone or iPad) or **Settings → Friends → Pods** (Mac). Enter a name and tap **Start a pod**.
2. Tap **Invite**. Send the share through **Messages**, or copy the link and send that.
3. On Apple ID B, open the message or the link and accept the iCloud share. Open Rayna if it does not come forward on its own.
4. On A, the grey tile (**Waiting to join**) becomes a normal member tile once B's app has published a Member record. That happens when B opens the pod screen or logs a glass.
5. Log water on each side.
   - The logger's own tile matches the main screen straight away, in litres and percent (for example `1.00 L · 31%`), and the tank fills with it.
   - The other person sees that total when their app is open, when they bring it forward, or within about a minute.
6. Tap **Nudge** on the other person's tile. The notification is the fixed line "{name} nudged you: time for a glass of water!". The limit is 3 nudges per person per day. There is nowhere to type a message.
7. **Leave pod** on the participant removes them from the pod. **End pod** on the owner deletes the zone. The other person's next refresh should show that the pod has ended.

## Debug builds only

A Debug build of the iOS app or the **RaynaMac** scheme shows a **Debug** section at the bottom of the pod screen. `./build.sh` is a release build and does not show it.

- **Fake pod members** draws Sam, Priya (a kid), Tom (over goal) and Noor, plus a sample invite for Alex. The tanks are local. Refresh, nudge, cancel and publish do not write those people to CloudKit. Turning the toggle on can award **Pod wave** once, using a local all-over roster. That badge is a normal unlock on the account. The sample people are not.
- The same section shows the share URL, how many share participants there are and whether each is accepted, pending or removed, the last pod fetch time, and whether the pod subscription is saved.
- **Refresh pod now** fetches the zone again.

## CloudKit Console

Open [CloudKit Console](https://icloud.developer.apple.com) with the team that owns the container.

1. Choose the container **iCloud.co.versantus.raynawater**.
2. Set the environment to **Development** or **Production**, the same one the builds are using.
3. Open **Data**.
4. The owner's records are in their **Private Database**, custom zone **RaynaPod**.
   - `Pod` is the root (`name`, `podStreak`, `podStreakDay`).
   - `Member` is one person (`userID`, `name`, `glasses`, `ml`, `goal`, `streak`, `isKid`, `updated`). `updated` is the day. There is no separate day field.
   - `Nudge` is `to`, `from`, `fromName`, `created`.
5. The participant sees the same zone under **Shared Database**, not in their private database.
6. The share is the `CKShare` in that zone. Its participants list pending and accepted people. A grey tile in the app is a pending participant. A member tile is a `Member` record.
7. **Schema → Record Types** is only to confirm nothing new was added. This work does not need a schema deploy.

If a Member row stays at `ml` 0 while that person's main screen shows water, they have not published since the pod was created. Opening the pod screen or logging a glass writes `ml`, `goal` and `updated`.
