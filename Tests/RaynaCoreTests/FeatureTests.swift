import CloudKit
import XCTest
@testable import RaynaCore

final class FeatureTests: XCTestCase {
    private func extras() -> RaynaExtras {
        let name = "rayna-feature-tests"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return RaynaExtras(defaults: d)
    }

    private func day(_ back: Int, from now: Date = Date()) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -back, to: now)!
        return RaynaCopy.dayKey(for: date)
    }

    @MainActor func testPodJoinHidesRawCloudKitErrors() {
        XCTAssertTrue(PodJoin.isOwnInvite(role: .owner, ownerRecordName: "owner", currentRecordName: "someone"))
        XCTAssertTrue(PodJoin.isOwnInvite(role: .privateUser, ownerRecordName: "me", currentRecordName: "me"))
        XCTAssertFalse(PodJoin.isOwnInvite(role: .privateUser, ownerRecordName: "owner", currentRecordName: "friend"))
        XCTAssertFalse(PodJoin.isOwnInvite(role: .privateUser, ownerRecordName: nil, currentRecordName: "friend"))

        let url = "Error accepting share at URL https://www.icloud.com/share/abc123 : owner participant tried to accept share"
        let owner = CKError(.serverRejectedRequest, userInfo: [NSLocalizedDescriptionKey: url])
        XCTAssertTrue(PodJoin.isOwnerAccept(owner))
        XCTAssertEqual(PodJoin.message(for: owner, joining: true), PodJoin.ownInvite)
        assertSafe(PodJoin.message(for: owner, joining: true))

        let wrapped = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue, userInfo: [
            NSUnderlyingErrorKey: owner
        ])
        XCTAssertTrue(PodJoin.isOwnerAccept(wrapped))
        assertSafe(PodJoin.message(for: wrapped, joining: true))

        let already = CKError(.serverRejectedRequest, userInfo: [
            NSLocalizedDescriptionKey: "The participant is already accepted on https://www.icloud.com/share/abc123"
        ])
        XCTAssertTrue(PodJoin.isAlreadyParticipant(already))
        XCTAssertEqual(PodJoin.message(for: already, joining: true), "You're already in this pod.")
        assertSafe(PodJoin.message(for: already, joining: true))

        assertSafe(PodJoin.message(for: CKError(.networkUnavailable), joining: true))
        XCTAssertTrue(PodJoin.message(for: CKError(.networkUnavailable)).contains("internet"))
        XCTAssertTrue(PodJoin.message(for: CKError(.notAuthenticated)).contains("Sign in to iCloud"))
        XCTAssertTrue(PodJoin.message(for: CKError(.quotaExceeded)).contains("storage is full"))
        XCTAssertEqual(PodJoin.message(for: CKError(.unknownItem), joining: true),
                       "That invite has been cancelled, or the pod no longer exists.")
        XCTAssertEqual(PodJoin.message(for: CKError(.zoneNotFound), joining: true), "That pod no longer exists.")
        XCTAssertEqual(PodJoin.message(for: CKError(.userDeletedZone)), "That pod no longer exists.")

        let leaked = CKError(.limitExceeded, userInfo: [
            NSLocalizedDescriptionKey: "See https://www.icloud.com/share/secret-token"
        ])
        assertSafe(PodService.friendly(leaked))
        XCTAssertFalse(PodService.friendly(leaked).contains("iCloud error"))
    }

    private func assertSafe(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(text.contains("http"), file: file, line: line)
        XCTAssertFalse(text.contains("icloud.com"), file: file, line: line)
        XCTAssertFalse(text.contains("CKError"), file: file, line: line)
        XCTAssertFalse(text.lowercased().contains("owner participant"), file: file, line: line)
    }

    func testMainLayoutAndExerciseDay() {
        XCTAssertEqual(MainLayout.decode(nil), .immersive)
        XCTAssertEqual(MainLayout.decode(""), .immersive)
        XCTAssertEqual(MainLayout.decode("nope"), .immersive)
        XCTAssertEqual(MainLayout.decode("hero"), .hero)
        XCTAssertEqual(MainLayout.decode("balanced"), .balanced)
        XCTAssertEqual(MainLayout.decode("immersive"), .immersive)

        var older = SyncSettings()
        older.text[MainLayout.storageKey] = SyncText("hero", at: Date(timeIntervalSince1970: 10))
        var newer = SyncSettings()
        newer.text[MainLayout.storageKey] = SyncText("balanced", at: Date(timeIntervalSince1970: 30))
        XCTAssertEqual(older.merged(with: newer).text[MainLayout.storageKey]?.value, "balanced")
        XCTAssertEqual(newer.merged(with: older).text[MainLayout.storageKey]?.value, "balanced")

        let bare = try? JSONDecoder().decode(SyncSettings.self, from: Data("{\"values\":{}}".utf8))
        XCTAssertEqual(bare?.text.count, 0)
        let encoded = try? JSONEncoder().encode(newer)
        let round = encoded.flatMap { try? JSONDecoder().decode(SyncSettings.self, from: $0) }
        XCTAssertEqual(round?.text[MainLayout.storageKey]?.value, "balanced")

        var ledger = SyncLedger()
        ledger.capture(SyncLocalSnapshot(today: "2026-10-17", text: [MainLayout.storageKey: "hero"]),
                       device: "phone", now: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(ledger.settings.text[MainLayout.storageKey]?.value, "hero")
        ledger.mergeRemote(newer)
        XCTAssertEqual(ledger.settings.text[MainLayout.storageKey]?.value, "balanced")

        let name = "rayna-layout-tests"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        let store = RaynaStore(defaults: d)
        store.goalML = 2500
        XCTAssertEqual(store.mainLayout, .immersive)
        XCTAssertTrue(store.exerciseExtraOn)
        XCTAssertEqual(store.effectiveGoal, 2500)
        store.runBonusML = 500
        store.runDay = true
        XCTAssertEqual(store.effectiveGoal, 3000)
        store.exerciseExtraOn = false
        XCTAssertEqual(store.effectiveGoal, 2500)
        store.runDay = false
        store.exerciseExtraOn = true
        XCTAssertEqual(store.effectiveGoal, 2500)
        XCTAssertEqual(ExerciseDay.goal(base: 2000, extraOn: true, exerciseDay: true, bonus: 500, kidMode: true), 2000)

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertTrue(ExerciseDay.hasHeavyWorkoutToday([ExerciseDay.Session(at: now, heavy: true)], now: now))
        XCTAssertFalse(ExerciseDay.hasHeavyWorkoutToday([ExerciseDay.Session(at: yesterday, heavy: true)], now: now))
        XCTAssertFalse(ExerciseDay.hasHeavyWorkoutToday([ExerciseDay.Session(at: now, heavy: false)], now: now))
        let today = RaynaCopy.dayKey(for: now)
        XCTAssertFalse(ExerciseDay.shouldAutoApply(extraOn: true, autoDetect: false, kidMode: false,
                                                    alreadyAppliedDay: "", today: today, hasHeavyToday: true))
        XCTAssertTrue(ExerciseDay.shouldAutoApply(extraOn: true, autoDetect: true, kidMode: false,
                                                   alreadyAppliedDay: "", today: today, hasHeavyToday: true))
        XCTAssertFalse(ExerciseDay.shouldAutoApply(extraOn: true, autoDetect: true, kidMode: false,
                                                    alreadyAppliedDay: today, today: today, hasHeavyToday: true))
        XCTAssertFalse(ExerciseDay.shouldAutoApply(extraOn: false, autoDetect: true, kidMode: false,
                                                    alreadyAppliedDay: "", today: today, hasHeavyToday: true))
    }

    func testGlassSizeValidation() {
        XCTAssertTrue(GlassSize.isValid(50))
        XCTAssertTrue(GlassSize.isValid(2000))
        XCTAssertFalse(GlassSize.isValid(49))
        XCTAssertFalse(GlassSize.isValid(2001))
        XCTAssertEqual(GlassSize.sanitize(0), 250)
        XCTAssertEqual(GlassSize.sanitize(1800), 1800)
        XCTAssertEqual(GlassSize.sanitize(5000), 2000)
        XCTAssertEqual(GlassSize.sanitize(10), 50)
        XCTAssertNil(GlassSize.validationMessage(for: "330"))
        XCTAssertNotNil(GlassSize.validationMessage(for: "20"))
        XCTAssertNotNil(GlassSize.validationMessage(for: "lots"))
        XCTAssertEqual(GlassSize.presets, [150, 200, 250, 330, 400, 500])
        XCTAssertTrue(GlassSize.isPreset(500))
        XCTAssertFalse(GlassSize.isPreset(175))
        XCTAssertEqual(GlassSize.customTag, -1)
        XCTAssertFalse(GlassSize.presets.contains(GlassSize.customTag))
        XCTAssertEqual(GlassSize.sanitize(GlassSize.customTag), 250)
        XCTAssertEqual(RaynaCopy.runDayLabel(bonusML: 500), "Exercise day (+500 ml)")
        XCTAssertEqual(RaynaCopy.exerciseDaySymbol, "dumbbell.fill")
        XCTAssertEqual(Double(RaynaStage.widthFraction), 0.90, accuracy: 0.001)
        // iPhone 13 content width after 16pt padding. Height has room, so she takes 90% of that slot (~83% of 390).
        XCTAssertEqual(Double(RaynaStage.side(width: 358, height: 420)), 358 * 0.90, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(Double(RaynaStage.side(width: 358, height: 420)) / 390, 0.80)
        XCTAssertLessThanOrEqual(Double(RaynaStage.side(width: 358, height: 420)) / 390, 0.90)
        // A short slot (iPhone SE with large type) shrinks her to the height instead of clipping.
        XCTAssertEqual(Double(RaynaStage.side(width: 343, height: 180)), 180, accuracy: 0.01)
        XCTAssertEqual(Double(RaynaStage.side(width: 0, height: 200)), 0, accuracy: 0.01)
        XCTAssertEqual(Double(RaynaStage.side(width: 200, height: 0)), 0, accuracy: 0.01)
        XCTAssertFalse(RaynaCopy.quip(for: 1).localizedCaseInsensitiveContains("race"))
        XCTAssertFalse(RaynaCopy.reminders.joined(separator: " ").localizedCaseInsensitiveContains("marathon"))
        XCTAssertEqual(RaynaUnlock.headband.title, "Workout headband")
        XCTAssertEqual(RaynaUnlock.medal.title, "Workout medal")
        XCTAssertEqual(RaynaUnlock.headband.rawValue, "headband")
        XCTAssertEqual(RaynaUnlock.medal.rawValue, "medal")
        XCTAssertFalse(RaynaUnlock.headband.blurb.localizedCaseInsensitiveContains("running"))
        let streakCard = RaynaShareInfo(kind: .streak(4), litres: 1, goalL: 2.5, streak: 4, weekL: 10, unlocks: [])
        XCTAssertEqual(streakCard.subtitle, "Hydration goal hit 4 days in a row")
        XCTAssertEqual(RaynaCopy.reminderMinutes, [30, 45, 60, 90, 120])
        XCTAssertLessThanOrEqual(RaynaCloudSync.saveDebounceSeconds, 1)
        XCTAssertEqual(RaynaCloudSync.fallbackPollSeconds, 60)
        XCTAssertEqual(RaynaCopy.addGlassLabel(glassML: 330, kidMode: false), "+1 glass · 330 ml")
        XCTAssertEqual(RaynaCopy.addGlassLabel(glassML: 200, kidMode: true), "+1 cup")
        XCTAssertEqual(RaynaCopy.amountTitle(ml: 500, glassML: 250, kidMode: true), "2 cups")
    }

    func testKidModeStaysBehindTheSharedFlag() {
        let x = extras()
        XCTAssertFalse(RaynaFeatures.kidMode)
        XCTAssertNil(x.applyKidMode(true, goalML: 2500, glassML: 330))
        XCTAssertFalse(x.kidMode)
        XCTAssertEqual(x.adultGoalML, 0)
    }

    func testCustomGlassSyncsAsExistingPref() {
        var phone = SyncSettings()
        phone.values["glassML"] = SyncStamped(250, at: Date(timeIntervalSince1970: 10))
        var mac = SyncSettings()
        mac.values["glassML"] = SyncStamped(1750, at: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(phone.merged(with: mac).values["glassML"]?.value, 1750)
        XCTAssertEqual(phone.merged(with: mac), mac.merged(with: phone))
    }

    func testInviteNameAndPendingFilter() {
        XCTAssertEqual(PodInviteList.displayName(formattedName: "Alex Kim", email: "a@b.co", phone: "+44"), "Alex Kim")
        XCTAssertEqual(PodInviteList.displayName(formattedName: "  ", email: "a@b.co", phone: nil), "a@b.co")
        XCTAssertEqual(PodInviteList.displayName(formattedName: nil, email: nil, phone: "+44 7700"), "+44 7700")
        XCTAssertEqual(PodInviteList.displayName(formattedName: nil, email: nil, phone: nil), "Invited")
        XCTAssertEqual(PodInviteList.participantKey(userRecordName: "abc", email: "A@B.co", phone: nil), "id:abc")
        XCTAssertEqual(PodInviteList.participantKey(userRecordName: nil, email: "A@B.co", phone: nil), "email:a@b.co")
        XCTAssertEqual(PodInviteList.participantKey(userRecordName: " ", email: nil, phone: "+1"), "phone:+1")

        let people = [
            InvitePerson(key: "id:me", name: "Nik", pending: false, isCurrentUser: true),
            InvitePerson(key: "email:sam@x.co", name: "Sam", pending: false, isCurrentUser: false),
            InvitePerson(key: "email:alex@x.co", name: "Alex", pending: true, isCurrentUser: false),
            InvitePerson(key: "", name: "", pending: true, isCurrentUser: false),
            InvitePerson(key: "phone:+44", name: "Me", pending: true, isCurrentUser: true)
        ]
        let pending = PodInviteList.pending(people)
        XCTAssertEqual(pending.map(\.id), ["email:alex@x.co", "pending-1"])
        XCTAssertEqual(pending.map(\.name), ["Alex", "Invited"])
    }

    func testStreakBadgesStaySeparateFromOverAchievers() {
        let x = extras()
        let earned = x.noteStreak(30)
        XCTAssertEqual(earned.map(\.rawValue), ["bubbles", "headband", "medal", "baby"])
        XCTAssertFalse(earned.contains(.surge))
        XCTAssertFalse(earned.contains(.podWave))
    }

    func testPercentBadgesAndPersonalBest() {
        let now = Date()
        let under = extras()
        under.recordDay(2499, now: now)
        let low = under.noteIntake(ml: 2499, goal: 2000, now: now)
        XCTAssertFalse(low.contains(.surge))
        XCTAssertFalse(low.contains(.personalBest))

        let big = extras()
        let first = big.noteIntake(ml: 4000, goal: 2000, now: now)
        XCTAssertEqual(first.map(\.rawValue), ["surge", "tide", "flood"])
        XCTAssertFalse(first.contains(.personalBest))

        let best = extras()
        best.history = [day(1, from: now): 1000]
        let got = best.noteIntake(ml: 1500, goal: 2500, now: now)
        XCTAssertEqual(got, [.personalBest])
        XCTAssertTrue(best.noteIntake(ml: 1800, goal: 2500, now: now).isEmpty)
    }

    func testExceedGoalStreakNeedsTodayOver() {
        let now = Date()
        let x = extras()
        x.history = [day(0, from: now): 2100, day(1, from: now): 2200, day(2, from: now): 2300]
        let got = x.noteIntake(ml: 2100, goal: 2000, now: now)
        XCTAssertTrue(got.contains(.over3))
        XCTAssertFalse(got.contains(.over7))

        let short = extras()
        short.history = [day(0, from: now): 2000, day(1, from: now): 2200, day(2, from: now): 2300, day(3, from: now): 2400]
        XCTAssertFalse(short.noteIntake(ml: 2000, goal: 2000, now: now).contains(.over3))
        XCTAssertEqual(short.exceedStreak(goal: 2000, now: now), 0)
    }

    func testPodWaveNeedsEveryoneStrictlyOver() {
        let now = Date()
        let over = PodMember(id: "a", name: "A", glasses: 11, ml: 2600, goal: 2500, streak: 1, updated: now)
        let met = PodMember(id: "b", name: "B", glasses: 10, ml: 2500, goal: 2500, streak: 1, updated: now)
        let also = PodMember(id: "c", name: "C", glasses: 8, ml: 1800, goal: 1500, streak: 1, updated: now)
        XCTAssertFalse(PodAchievement.everyoneBeatGoal([over]))
        XCTAssertFalse(PodAchievement.everyoneBeatGoal([over, met]))
        XCTAssertTrue(PodAchievement.everyoneBeatGoal([over, also]))
        let x = extras()
        XCTAssertEqual(x.notePodOverAchieved(false), [])
        XCTAssertEqual(x.notePodOverAchieved(true), [.podWave])
        XCTAssertTrue(x.notePodOverAchieved(true).isEmpty)
    }

    func testLocalPodTileUsesTodaysMillilitres() {
        let stale = PodMember(id: "me", name: "Bob", glasses: 0, ml: 0, goal: 2500, streak: 0, updated: .distantPast)
        let live = PodLive(glasses: 4, ml: 1000, goal: 3200, streak: 3, isKid: false)
        let now = Date()
        let me = PodTile.shown(stale, myID: "me", live: live, now: now)
        XCTAssertEqual(stale.ml, 0)
        XCTAssertEqual(me.ml, 1000)
        XCTAssertEqual(me.goal, 3200)
        XCTAssertEqual(me.glasses, 4)
        XCTAssertEqual(me.todayProgress, 1000.0 / 3200.0, accuracy: 0.0001)
        XCTAssertEqual(RaynaCopy.podTileLabel(me), "1.00 L · 31%")
        XCTAssertEqual(RaynaCopy.percent(ml: 1000, goal: 3200), 31)

        let byRecordName = PodTile.shown(
            PodMember(id: "member-me", name: "Bob", glasses: 0, ml: 0, goal: 2500, streak: 0, updated: .distantPast),
            myID: "me", live: live, now: now)
        XCTAssertEqual(RaynaCopy.podTileLabel(byRecordName), "1.00 L · 31%")

        let other = PodTile.shown(stale, myID: "someone-else", live: live, now: now)
        XCTAssertEqual(other.ml, 0)
        XCTAssertEqual(other.todayProgress, 0, accuracy: 0.0001)
        XCTAssertEqual(RaynaCopy.podTileLabel(other), "0.00 L · 0%")

        let friend = PodMember(id: "sam", name: "Sam", glasses: 0, ml: 1000, goal: 3200, streak: 1, updated: now)
        XCTAssertEqual(friend.todayProgress, 1000.0 / 3200.0, accuracy: 0.0001)
        XCTAssertEqual(RaynaCopy.podTileLabel(friend), "1.00 L · 31%")
        XCTAssertEqual(PodTile.cloudInt(NSNumber(value: Int64(1000))), 1000)
        XCTAssertEqual(PodTile.cloudInt(Double(1000)), 1000)
        XCTAssertEqual(PodTile.cloudInt(Int64(1000)), 1000)
        XCTAssertNil(PodTile.cloudInt("1000"))
    }

    func testOneWornBadgeAndLocalFakePod() {
        let all = Array(RaynaUnlock.allCases)
        XCTAssertEqual(WornBadge.worn(code: WornBadge.automatic, unlocked: all), all.last)
        XCTAssertNil(WornBadge.worn(code: WornBadge.none, unlocked: all))
        let head = WornBadge.code(for: .headband)
        XCTAssertEqual(WornBadge.unlock(code: head), .headband)
        XCTAssertEqual(WornBadge.worn(code: head, unlocked: all), .headband)
        XCTAssertEqual(WornBadge.worn(code: head, unlocked: [.bubbles]), .bubbles)
        XCTAssertEqual(WornBadge.single(in: [.headband]), .headband)
        XCTAssertEqual(WornBadge.single(in: [.bubbles, .headband]), .headband)
        XCTAssertEqual(WornBadge.single(in: [.headband, .tide, .bubbles, .flood]), .flood)
        XCTAssertTrue(RaynaUnlock.tide.isSceneOverlay)
        XCTAssertTrue(RaynaUnlock.flood.isSceneOverlay)
        XCTAssertTrue(RaynaUnlock.podWave.isSceneOverlay)
        XCTAssertFalse(RaynaUnlock.headband.isSceneOverlay)
        XCTAssertTrue(RaynaUnlock.surge.isSceneOverlay)
        XCTAssertFalse(RaynaUnlock.personalBest.isSceneOverlay)
        XCTAssertTrue(SyncLocalDefaults.intSettings.contains(WornBadge.prefsKey))

        let fakes = PodFakeRoster.members()
        XCTAssertTrue((3...4).contains(fakes.count))
        XCTAssertEqual(fakes.filter(\.isKid).count, 1)
        XCTAssertEqual(fakes.filter { $0.ml > $0.goal }.count, 1)
        XCTAssertGreaterThan(Set(fakes.map(\.goal)).count, 1)
        XCTAssertTrue(fakes.allSatisfy { PodFakeRoster.isFake($0.id) })
        XCTAssertEqual(PodFakeRoster.invites().count, 1)
        XCTAssertTrue(PodFakeRoster.isFake(PodFakeRoster.invites()[0].id))
        XCTAssertTrue(PodAchievement.everyoneBeatGoal(PodFakeRoster.wave()))
        XCTAssertFalse(PodAchievement.everyoneBeatGoal(fakes))
    }

    func testWearUpToThreeBadges() {
        let slots = Dictionary(grouping: RaynaUnlock.allCases, by: \.slot)
        XCTAssertEqual(Set(slots.keys), Set(BadgeSlot.allCases))
        XCTAssertEqual(slots.values.flatMap { $0 }.count, RaynaUnlock.allCases.count)
        XCTAssertEqual(RaynaUnlock.headband.slot, .head)
        XCTAssertEqual(RaynaUnlock.over30.slot, .head)
        XCTAssertEqual(RaynaUnlock.medal.slot, .chest)
        XCTAssertEqual(RaynaUnlock.over7.slot, .chest)
        XCTAssertEqual(RaynaUnlock.personalBest.slot, .fin)
        XCTAssertEqual(RaynaUnlock.podWave.slot, .scene)
        XCTAssertEqual(RaynaUnlock.surge.slot, .scene)
        XCTAssertEqual(RaynaUnlock.tide.slot, .scene)
        XCTAssertTrue(RaynaUnlock.allCases.filter { $0.slot == .scene }.allSatisfy(\.isSceneOverlay))
        XCTAssertEqual(WornSet.toggling([.over30, .personalBest], .flood).set, [.over30, .personalBest, .flood], "a scene is worn alongside body badges")
        XCTAssertEqual(WornSet.normalized(Set(RaynaUnlock.allCases)).count, BadgeSlot.allCases.count)

        var wearing: Set<RaynaUnlock> = [.headband, .medal]
        let swapped = WornSet.toggling(wearing, .over30)
        XCTAssertEqual(swapped.replaced, .headband)
        XCTAssertEqual(swapped.set, [.over30, .medal])
        let removed = WornSet.toggling(swapped.set, .medal)
        XCTAssertNil(removed.replaced)
        XCTAssertEqual(removed.set, [.over30])
        wearing = [.headband]
        XCTAssertEqual(WornSet.autoWear(wearing, fresh: [.over30, .medal]), [.headband, .medal])
        XCTAssertEqual(WornSet.autoWear([.medal], fresh: [.over7]), [.medal])

        XCTAssertEqual(WornSet.migrated(from: WornBadge.code(for: .medal), unlocked: [.bubbles, .medal]), [.medal])
        XCTAssertEqual(WornSet.migrated(from: WornBadge.none, unlocked: [.medal]), [])
        XCTAssertEqual(WornSet.migrated(from: WornBadge.automatic, unlocked: [.bubbles, .headband]), [.headband])
        let bits = WornSet.bits([.headband, .medal, .personalBest])
        XCTAssertEqual(WornSet.badges(from: bits), [.headband, .medal, .personalBest])

        let name = "rayna-worn-set"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let extras = RaynaExtras(defaults: defaults)
        defaults.set(WornBadge.code(for: .headband), forKey: WornBadge.prefsKey)
        extras.unlocked = [.headband, .medal]
        XCTAssertEqual(extras.wornBadges, [.headband])
        XCTAssertNil(defaults.object(forKey: WornSet.prefsKey))
        let fresh = extras.unlockForTesting([.personalBest, .over30])
        XCTAssertEqual(fresh, [.personalBest, .over30])
        XCTAssertEqual(extras.wornBadges, [.headband, .personalBest])
        XCTAssertNotNil(defaults.object(forKey: WornSet.prefsKey))

        var older = SyncSettings()
        older.values[WornSet.prefsKey] = SyncStamped(WornSet.bits([.headband]), at: Date(timeIntervalSince1970: 10))
        var newer = SyncSettings()
        newer.values[WornSet.prefsKey] = SyncStamped(WornSet.bits([.medal]), at: Date(timeIntervalSince1970: 30))
        XCTAssertEqual(older.merged(with: newer).values[WornSet.prefsKey]?.value, WornSet.bits([.medal]))
        let encoded = try? JSONEncoder().encode(newer)
        let round = encoded.flatMap { try? JSONDecoder().decode(SyncSettings.self, from: $0) }
        XCTAssertEqual(round?.values[WornSet.prefsKey]?.value, WornSet.bits([.medal]))
        let bare = try? JSONDecoder().decode(SyncSettings.self, from: Data("{\"values\":{}}".utf8))
        XCTAssertNil(bare?.values[WornSet.prefsKey])
        XCTAssertTrue(SyncLocalDefaults.intSettings.contains(WornSet.prefsKey))

        let syncName = "rayna-worn-sync"
        let syncDefaults = UserDefaults(suiteName: syncName)!
        syncDefaults.removePersistentDomain(forName: syncName)
        let missing = SyncLocalDefaults(syncDefaults).read()
        XCTAssertNil(missing.settings[WornSet.prefsKey])
        syncDefaults.set(WornSet.bits([.medal]), forKey: WornSet.prefsKey)
        XCTAssertEqual(SyncLocalDefaults(syncDefaults).read().settings[WornSet.prefsKey], WornSet.bits([.medal]))
    }

    func testQuipCatalogCountsBannedWordsAndShuffle() {
        let expected = ["start", "ripple", "glide", "halfway", "rising", "almost", "goal", "reminder", "exercise", "kid"]
        XCTAssertEqual(Set(QuipCatalog.categories.map(\.id)), Set(expected))
        XCTAssertGreaterThanOrEqual(QuipCatalog.totalCount, 250)
        XCTAssertTrue(QuipCatalog.allKidSafe)
        var seen = Set<String>()
        let banned: Set<String> = [
            "calves", "calf", "race", "races", "racing", "marathon", "sprint", "sprints",
            "jog", "jogging", "jogger", "runner", "running", "runs", "run",
            "beer", "wine", "wines", "pint", "pints", "alcohol", "alcoholic", "drunk",
            "cocktail", "booze", "lager", "cider", "champagne", "vodka", "whiskey", "whisky", "pub",
            "sexy", "naughty", "flirt", "innuendo",
            "fat", "skinny", "obese", "chubby", "flabby", "calorie", "calories", "diet", "diets",
            "detox", "cleanse", "fasting", "slim", "slimming",
            "cure", "cures", "diagnose", "diagnosis", "disease", "diabetes", "prescription",
            "illness", "symptom", "symptoms", "medical", "medicine",
            "guilt", "guilty", "shame", "shaming", "hangover",
            "weight", "weigh", "thigh", "thighs", "belly", "butt",
            "damn", "hell", "crap"
        ]
        for cat in QuipCatalog.categories {
            XCTAssertGreaterThanOrEqual(cat.lines.count, 30, cat.id)
            XCTAssertEqual(Set(cat.lines.compactMap(\.time)), Set(["morning", "afternoon", "evening", "night"]), cat.id)
            XCTAssertTrue(cat.lines.contains { $0.time == nil }, cat.id)
            var own = Set<String>()
            for line in cat.lines {
                XCTAssertTrue(own.insert(line.text).inserted, "\(cat.id) repeats \(line.text)")
                XCTAssertTrue(seen.insert(line.text).inserted, line.text)
                XCTAssertTrue(line.kidSafe)
                XCTAssertGreaterThanOrEqual(line.text.count, 12, line.text)
                XCTAssertLessThanOrEqual(line.text.count, 100, line.text)
                let words = line.text.lowercased().split { !$0.isLetter }.map(String.init)
                XCTAssertTrue(banned.isDisjoint(with: words), "\(line.text) uses \(banned.intersection(words))")
            }
        }
        let exercise = QuipCatalog.lines(id: "exercise").map(\.text).joined(separator: " ").lowercased()
        for word in ["exercise", "workout", "moving", "playing", "swimming"] {
            XCTAssertTrue(exercise.contains(word), word)
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        func at(_ hour: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: hour))!
        }
        XCTAssertEqual(QuipCatalog.dayPart(for: at(5), calendar: cal), "morning")
        XCTAssertEqual(QuipCatalog.dayPart(for: at(11), calendar: cal), "morning")
        XCTAssertEqual(QuipCatalog.dayPart(for: at(12), calendar: cal), "afternoon")
        XCTAssertEqual(QuipCatalog.dayPart(for: at(16), calendar: cal), "afternoon")
        XCTAssertEqual(QuipCatalog.dayPart(for: at(17), calendar: cal), "evening")
        XCTAssertEqual(QuipCatalog.dayPart(for: at(20), calendar: cal), "evening")
        XCTAssertEqual(QuipCatalog.dayPart(for: at(21), calendar: cal), "night")
        XCTAssertEqual(QuipCatalog.dayPart(for: at(4), calendar: cal), "night")

        XCTAssertEqual(QuipCatalog.situation(for: 0, kidMode: false, exerciseDay: false), "start")
        XCTAssertEqual(QuipCatalog.situation(for: 0.14, kidMode: false, exerciseDay: false), "start")
        XCTAssertEqual(QuipCatalog.situation(for: 0.15, kidMode: false, exerciseDay: false), "ripple")
        XCTAssertEqual(QuipCatalog.situation(for: 0.35, kidMode: false, exerciseDay: false), "glide")
        XCTAssertEqual(QuipCatalog.situation(for: 0.55, kidMode: false, exerciseDay: false), "halfway")
        XCTAssertEqual(QuipCatalog.situation(for: 0.75, kidMode: false, exerciseDay: false), "rising")
        XCTAssertEqual(QuipCatalog.situation(for: 0.9, kidMode: false, exerciseDay: false), "almost")
        XCTAssertEqual(QuipCatalog.situation(for: 0.99, kidMode: false, exerciseDay: false), "almost")
        XCTAssertEqual(QuipCatalog.situation(for: 1, kidMode: false, exerciseDay: true), "goal")
        XCTAssertEqual(QuipCatalog.situation(for: 0.4, kidMode: false, exerciseDay: true), "exercise")
        XCTAssertEqual(QuipCatalog.situation(for: 0.4, kidMode: true, exerciseDay: true), "glide")

        let morning = Set(QuipCatalog.pool(id: "start", at: at(9), kidMode: false, calendar: cal))
        let nightLine = QuipCatalog.lines(id: "start").first { $0.time == "night" }!
        let anyLine = QuipCatalog.lines(id: "start").first { $0.time == nil }!
        let morningLine = QuipCatalog.lines(id: "start").first { $0.time == "morning" }!
        XCTAssertFalse(morning.contains(nightLine.text))
        XCTAssertTrue(morning.contains(anyLine.text))
        XCTAssertTrue(morning.contains(morningLine.text))

        let adult = QuipCatalog.pool(id: "glide", at: at(9), kidMode: false, calendar: cal)
        let kid = QuipCatalog.pool(id: "glide", at: at(9), kidMode: true, calendar: cal)
        XCTAssertTrue(adult.allSatisfy { kid.contains($0) })
        XCTAssertTrue(QuipCatalog.pool(id: "kid", at: at(9), kidMode: false, calendar: cal).allSatisfy { kid.contains($0) })

        final class Seed { var state: UInt64 = 1 }
        let seed = Seed()
        let sample = (1...30).map { "Line \($0)" }
        let bag = QuipShuffleBag(lines: sample) {
            seed.state = seed.state &* 6364136223846793005 &+ 1
            return seed.state
        }
        var previous = ""
        for _ in 0..<3 {
            var cycle = Set<String>()
            for _ in sample {
                let next = bag.next()
                XCTAssertNotEqual(next, previous)
                XCTAssertTrue(cycle.insert(next).inserted)
                previous = next
            }
        }

        QuipPicker.shared.reset()
        let first = RaynaCopy.quip(for: 0.4, at: at(9), salt: 100, calendar: cal)
        XCTAssertEqual(first, RaynaCopy.quip(for: 0.4, at: at(9), salt: 100, calendar: cal))
        XCTAssertNotEqual(first, RaynaCopy.quip(for: 0.4, at: at(9), salt: 101, calendar: cal))
        XCTAssertTrue(adult.contains(first))
        let exerciseLine = RaynaCopy.quip(for: 0.4, at: at(9), exerciseDay: true, salt: 3, calendar: cal)
        XCTAssertTrue(QuipCatalog.pool(id: "exercise", at: at(9), kidMode: false, calendar: cal).contains(exerciseLine))
        let goalLine = RaynaCopy.quip(for: 1, at: at(9), exerciseDay: true, salt: 4, calendar: cal)
        XCTAssertTrue(QuipCatalog.pool(id: "goal", at: at(9), kidMode: false, calendar: cal).contains(goalLine))
        let kidLine = RaynaCopy.kidQuip(for: 0.4, at: at(9), salt: 7, calendar: cal)
        XCTAssertTrue(kid.contains(kidLine))
        previous = ""
        for _ in 0..<40 {
            let reminder = RaynaCopy.nextReminder(at: at(10), calendar: cal)
            XCTAssertNotEqual(reminder, previous)
            XCTAssertTrue(QuipCatalog.lines(id: "reminder").map(\.text).contains(reminder))
            previous = reminder
        }
    }

    func testUnlockForTestingAndAssetNames() {
        let x = extras()
        XCTAssertEqual(x.unlockForTesting([.surge, .podWave, .surge]), [.surge, .podWave])
        XCTAssertEqual(x.unlocked, [.surge, .podWave])
        let rest = x.unlockForTesting(RaynaExtras.badges(from: "all"))
        XCTAssertEqual(rest.count, RaynaUnlock.allCases.count - 2)
        XCTAssertEqual(Set(x.unlocked), Set(RaynaUnlock.allCases))
        XCTAssertTrue(x.unlockForTesting(RaynaExtras.badges(from: "ALL")).isEmpty)
        XCTAssertEqual(RaynaExtras.badges(from: " surge, tide ,nope"), [.surge, .tide])
        XCTAssertEqual(RaynaUnlock.surge.overlayAssetName, "badge-surge-overlay")
        XCTAssertEqual(RaynaUnlock.personalBest.compositeAssetName, "badge-personalBest")
        XCTAssertNil(RaynaUnlock.bubbles.overlayAssetName)
        XCTAssertNil(RaynaUnlock.headband.compositeAssetName)
    }

    func testNewUnlockNamesSyncAsProfileUnion() {
        var a = SyncProfile(); a.unlocks = ["bubbles", "surge"]
        var b = SyncProfile(); b.unlocks = ["podWave"]
        XCTAssertEqual(a.merged(with: b).unlocks, Set(["bubbles", "podWave", "surge"]))
    }
}