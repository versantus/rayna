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
        XCTAssertEqual(RaynaCopy.reminderMinutes, [30, 45, 60, 90, 120])
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