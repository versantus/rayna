import XCTest
@testable import RaynaCore

final class SeasonTests: XCTestCase {
    private func defaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func calendar(_ id: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: id)!
        return cal
    }

    private func date(_ cal: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testAutomaticWindowIncludesTheFirstAndLastDay() {
        let london = calendar("Europe/London")
        let d = defaults("rayna-season-window")
        XCTAssertEqual(SeasonGate.phase(now: date(london, 2026, 10, 16, 23, 59), calendar: london), .closed)
        XCTAssertFalse(SeasonGate.isShowing(now: date(london, 2026, 10, 16), calendar: london, defaults: d))
        XCTAssertEqual(SeasonGate.phase(now: date(london, 2026, 10, 17, 0, 0), calendar: london), .automatic)
        XCTAssertTrue(SeasonGate.isShowing(now: date(london, 2026, 10, 17, 0, 0), calendar: london, defaults: d))
        XCTAssertTrue(SeasonGate.isShowing(now: date(london, 2026, 11, 1, 23, 0), calendar: london, defaults: d))
        XCTAssertEqual(SeasonGate.phase(now: date(london, 2026, 11, 2, 0, 0), calendar: london), .manual)
        XCTAssertFalse(SeasonGate.isShowing(now: date(london, 2026, 11, 2, 0, 0), calendar: london, defaults: d))
    }

    func testManualWindowIsOffUntilTurnedOnAndClosesAfter15November() {
        let london = calendar("Europe/London")
        let d = defaults("rayna-season-manual")
        let nov2 = date(london, 2026, 11, 2, 0, 0)
        let nov15 = date(london, 2026, 11, 15, 23, 0)
        let nov16 = date(london, 2026, 11, 16, 0, 0)
        XCTAssertTrue(SeasonGate.settingsAvailable(now: nov2, calendar: london))
        XCTAssertTrue(SeasonGate.settingsAvailable(now: nov15, calendar: london))
        XCTAssertFalse(SeasonGate.isShowing(now: nov2, calendar: london, defaults: d))
        XCTAssertFalse(SeasonGate.isShowing(now: nov15, calendar: london, defaults: d))
        SeasonGate.setCostume(true, defaults: d, now: nov2, calendar: london)
        XCTAssertTrue(SeasonGate.isShowing(now: nov2, calendar: london, defaults: d))
        XCTAssertTrue(SeasonGate.isShowing(now: nov15, calendar: london, defaults: d))
        XCTAssertEqual(SeasonGate.phase(now: nov16, calendar: london), .closed)
        XCTAssertFalse(SeasonGate.settingsAvailable(now: nov16, calendar: london))
        XCTAssertFalse(SeasonGate.isShowing(now: nov16, calendar: london, defaults: d))
    }

    func testOptOutOnlyAppliesInsideTheAutomaticWindow() {
        let london = calendar("Europe/London")
        let d = defaults("rayna-season-opt")
        let oct31 = date(london, 2026, 10, 31)
        XCTAssertTrue(SeasonGate.isShowing(now: oct31, calendar: london, defaults: d), "a missing key means on")
        SeasonGate.setCostume(false, defaults: d, now: oct31, calendar: london)
        XCTAssertEqual(d.bool(forKey: SeasonGate.halloween.offKey), true)
        XCTAssertFalse(SeasonGate.isShowing(now: oct31, calendar: london, defaults: d))
        SeasonGate.setCostume(true, defaults: d, now: oct31, calendar: london)
        XCTAssertFalse(d.bool(forKey: SeasonGate.halloween.offKey))
        XCTAssertTrue(SeasonGate.isShowing(now: oct31, calendar: london, defaults: d))
        // An explicit "on" in October does not keep the cape on from 2 November.
        XCTAssertFalse(SeasonGate.isShowing(now: date(london, 2026, 11, 3), calendar: london, defaults: d))
    }

    func testLocalCalendarWinsAcrossTimeZones() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let instant = utc.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 22))!
        let london = calendar("Europe/London")
        let auckland = calendar("Pacific/Auckland")
        XCTAssertEqual(london.component(.day, from: instant), 16)
        XCTAssertEqual(auckland.component(.day, from: instant), 17)
        let d = defaults("rayna-season-tz")
        XCTAssertFalse(SeasonGate.isShowing(now: instant, calendar: london, defaults: d))
        XCTAssertTrue(SeasonGate.isShowing(now: instant, calendar: auckland, defaults: d))

        let londonMorning = date(london, 2026, 10, 17, 0, 30)
        let losAngeles = calendar("America/Los_Angeles")
        XCTAssertEqual(losAngeles.component(.day, from: londonMorning), 16)
        XCTAssertTrue(SeasonGate.isShowing(now: londonMorning, calendar: london, defaults: d))
        XCTAssertFalse(SeasonGate.isShowing(now: londonMorning, calendar: losAngeles, defaults: d))
    }

    func testLondonClockChangeStaysInsideTheWindow() {
        let london = calendar("Europe/London")
        let d = defaults("rayna-season-dst")
        XCTAssertTrue(SeasonGate.isShowing(now: date(london, 2026, 10, 25, 0, 30), calendar: london, defaults: d))
        XCTAssertTrue(SeasonGate.isShowing(now: date(london, 2026, 10, 25, 3, 30), calendar: london, defaults: d))
    }

    func testYearGuardAndFeatureFlagAndForce() {
        let london = calendar("Europe/London")
        let d = defaults("rayna-season-year")
        XCTAssertFalse(SeasonGate.isShowing(now: date(london, 1970, 10, 31), calendar: london, defaults: d))
        XCTAssertFalse(SeasonGate.isShowing(now: date(london, 2040, 10, 31), calendar: london, defaults: d))
        XCTAssertFalse(SeasonGate.settingsAvailable(now: date(london, 1970, 10, 31), calendar: london))
        XCTAssertFalse(SeasonGate.isShowing(now: date(london, 2026, 10, 31), calendar: london, defaults: d, featuresOn: false))
        XCTAssertTrue(SeasonGate.isShowing(now: date(london, 2026, 6, 1), calendar: london, defaults: d, force: .showing))
        XCTAssertFalse(SeasonGate.isShowing(now: date(london, 2026, 10, 31), calendar: london, defaults: d, force: .hidden))
        XCTAssertEqual(SeasonGate.environmentForce(["RAYNA_SEASON": "halloween"]), .showing)
        XCTAssertEqual(SeasonGate.environmentForce(["RAYNA_SEASON": "off"]), .hidden)
        XCTAssertEqual(SeasonGate.environmentForce(["SIMCTL_CHILD_RAYNA_SEASON": "halloween"]), .showing)
        XCTAssertEqual(SeasonGate.environmentForce([:]), .none)
        XCTAssertNil(d.object(forKey: "RAYNA_SEASON"))
    }

    func testWindowThatCrossesNewYear() {
        let winter = SeasonWindow(id: .halloween, startMonth: 12, startDay: 20, endMonth: 1, endDay: 5,
                                  manualEndMonth: 1, manualEndDay: 15, offKey: "halloweenOff", manualOnKey: "halloweenManualOn",
                                  firstYear: 2026, lastYear: 2035)
        let london = calendar("Europe/London")
        XCTAssertEqual(SeasonGate.phase(winter, now: date(london, 2026, 12, 20), calendar: london), .automatic)
        XCTAssertEqual(SeasonGate.phase(winter, now: date(london, 2027, 1, 1), calendar: london), .automatic)
        XCTAssertEqual(SeasonGate.phase(winter, now: date(london, 2027, 1, 5), calendar: london), .automatic)
        XCTAssertEqual(SeasonGate.phase(winter, now: date(london, 2027, 1, 6), calendar: london), .manual)
        XCTAssertEqual(SeasonGate.phase(winter, now: date(london, 2027, 1, 15), calendar: london), .manual)
        XCTAssertEqual(SeasonGate.phase(winter, now: date(london, 2027, 1, 16), calendar: london), .closed)
        XCTAssertEqual(SeasonGate.phase(winter, now: date(london, 2026, 12, 19), calendar: london), .closed)
    }

    func testHalloweenPrefsAreNotUploadedUntilSet() {
        let d = defaults("rayna-season-sync")
        let missing = SyncLocalDefaults(d).read()
        XCTAssertNil(missing.settings[SeasonGate.halloween.offKey])
        XCTAssertNil(missing.settings[SeasonGate.halloween.manualOnKey])
        d.set(true, forKey: SeasonGate.halloween.offKey)
        d.set(false, forKey: SeasonGate.halloween.manualOnKey)
        let set = SyncLocalDefaults(d).read()
        XCTAssertEqual(set.settings[SeasonGate.halloween.offKey], 1)
        XCTAssertEqual(set.settings[SeasonGate.halloween.manualOnKey], 0)

        var remote = SyncSettings()
        remote.values[SeasonGate.halloween.manualOnKey] = SyncStamped(1, at: Date(timeIntervalSince1970: 50))
        var ledger = SyncLedger()
        ledger.capture(missing, device: "a", now: Date(timeIntervalSince1970: 10))
        ledger.mergeRemote(remote)
        let applied = ledger.snapshot(from: missing)
        XCTAssertEqual(applied.settings[SeasonGate.halloween.manualOnKey], 1)
        SyncLocalDefaults(d).write(applied, over: missing)
        XCTAssertEqual(d.bool(forKey: SeasonGate.halloween.manualOnKey), true)
    }

    func testHalloweenFactsMergeByMaxAndOldProfilesStillDecode() throws {
        var low = SyncProfile(); low.halloweenFactsShown = 2; low.factsUnlocked = 3
        var high = SyncProfile(); high.halloweenFactsShown = 5
        XCTAssertEqual(low.merged(with: high).halloweenFactsShown, 5)
        XCTAssertEqual(high.merged(with: low).halloweenFactsShown, 5)
        XCTAssertEqual(low.merged(with: high).factsUnlocked, 3)
        let encoded = try JSONEncoder().encode(low)
        let round = try JSONDecoder().decode(SyncProfile.self, from: encoded)
        XCTAssertEqual(round.halloweenFactsShown, 2)
        let old = Data("{\"streak\":1,\"lastGoalDay\":\"2026-10-01\",\"bestStreak\":1,\"unlocks\":[\"medal\"],\"goalDays\":[],\"factsUnlocked\":4}".utf8)
        let decoded = try JSONDecoder().decode(SyncProfile.self, from: old)
        XCTAssertEqual(decoded.factsUnlocked, 4)
        XCTAssertEqual(decoded.halloweenFactsShown, 0)
        XCTAssertEqual(decoded.unlocks, ["medal"])
    }

    func testMoonleapStaysAStringAndOutOfTheWearMask() {
        XCTAssertEqual(RaynaUnlock.allCases.last, .turtles)
        XCTAssertNil(RaynaUnlock(rawValue: SeasonStamp.id))
        let d = defaults("rayna-season-stamp")
        let extras = RaynaExtras(defaults: d)
        d.set([SeasonStamp.id, "medal"], forKey: "unlocks")
        XCTAssertEqual(extras.unlockForTesting([.surge]), [.surge])
        let stored = d.stringArray(forKey: "unlocks") ?? []
        XCTAssertTrue(stored.contains(SeasonStamp.id))
        XCTAssertFalse(extras.unlocked.map(\.rawValue).contains(SeasonStamp.id))
        // Surge takes the scene slot. The stamp is not a badge, so it cannot sit in that set.
        XCTAssertEqual(extras.wornBadges, [.surge])
        SeasonGate.setCostume(false, defaults: d, now: date(calendar("Europe/London"), 2026, 10, 20), calendar: calendar("Europe/London"))
        XCTAssertTrue((d.stringArray(forKey: "unlocks") ?? []).contains(SeasonStamp.id))
        XCTAssertNotEqual(d.string(forKey: RaynaSkin.storageKey), "halloween")

        var a = SyncProfile(); a.unlocks = [SeasonStamp.id]
        var b = SyncProfile(); b.unlocks = ["bubbles"]
        XCTAssertEqual(a.merged(with: b).unlocks, [SeasonStamp.id, "bubbles"])
    }

    func testMoonleapCardHidesOffSeasonAndDoesNotNeedEarningAgain() {
        let london = calendar("Europe/London")
        let d = defaults("rayna-season-card")
        let extras = RaynaExtras(defaults: d)
        let oct31 = date(london, 2026, 10, 31, 18)
        XCTAssertFalse(extras.hasMoonleap)
        XCTAssertTrue(extras.awardMoonleapIfNeeded(ml: 2500, goal: 2500, now: oct31, calendar: london))
        XCTAssertFalse(extras.awardMoonleapIfNeeded(ml: 2500, goal: 2500, now: oct31, calendar: london))
        XCTAssertTrue(SeasonStamp.showsCard(showing: SeasonGate.isShowing(now: oct31, calendar: london, defaults: d)))
        let nov2 = date(london, 2026, 11, 2)
        XCTAssertFalse(SeasonStamp.showsCard(showing: SeasonGate.isShowing(now: nov2, calendar: london, defaults: d)))
        let nextYear = date(london, 2027, 10, 17)
        XCTAssertTrue(extras.hasMoonleap)
        XCTAssertTrue(SeasonGate.isShowing(now: nextYear, calendar: london, defaults: d))
        XCTAssertFalse(extras.awardMoonleapIfNeeded(ml: 100, goal: 2500, now: oct31, calendar: london))
        XCTAssertFalse(extras.awardMoonleapIfNeeded(ml: 2500, goal: 2500, now: date(london, 2026, 10, 16), calendar: london))
    }

    func testHalloweenLinesReplaceTheProgressPoolAndStayOutOfReminders() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let at = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9))!
        let halloween = Set(QuipCatalog.lines(id: "halloween").map(\.text))
        let shown = QuipCatalog.pool(id: "glide", at: at, kidMode: false, calendar: cal, seasonal: true)
        let hidden = QuipCatalog.pool(id: "glide", at: at, kidMode: false, calendar: cal, seasonal: false)
        XCTAssertEqual(Set(shown), halloween)
        XCTAssertTrue(Set(hidden).isDisjoint(with: halloween))
        let kid = QuipCatalog.pool(id: "glide", at: at, kidMode: true, calendar: cal, seasonal: true)
        XCTAssertEqual(Set(kid), halloween, "kid lines are not mixed in while the cape is on")
        let exercise = QuipCatalog.pool(id: "exercise", at: at, kidMode: false, calendar: cal, seasonal: true)
        XCTAssertEqual(Set(exercise), halloween)
        let reminder = Set(QuipCatalog.pool(id: "reminder", at: at, kidMode: false, calendar: cal, seasonal: true))
        let goal = Set(QuipCatalog.pool(id: "goal", at: at, kidMode: false, calendar: cal, seasonal: true))
        XCTAssertTrue(reminder.isDisjoint(with: halloween))
        XCTAssertTrue(goal.isDisjoint(with: halloween))
        XCTAssertEqual(reminder, Set(QuipCatalog.pool(id: "reminder", at: at, kidMode: false, calendar: cal, seasonal: false)))

        let banned: Set<String> = ["blood", "gore", "death", "kill", "scary", "fright", "scream", "trick",
                                   "haunt", "zombie", "skeleton", "devil", "mwah"]
        for line in QuipCatalog.lines(id: "halloween") {
            XCTAssertTrue(line.kidSafe)
            XCTAssertTrue(line.text.contains("Ray"))
            XCTAssertFalse(line.text.contains("Rayna"))
            let words = line.text.lowercased().split { !$0.isLetter }.map(String.init)
            XCTAssertTrue(banned.isDisjoint(with: words), line.text)
            for phrase in ["last chance", "before it's gone", "only 1 day", "only 2 days"] {
                XCTAssertFalse(line.text.localizedCaseInsensitiveContains(phrase), line.text)
            }
        }
        for line in SeasonCopy.treats {
            XCTAssertFalse(line.localizedCaseInsensitiveContains("trick"))
            XCTAssertFalse(line.contains("Rayna"))
            XCTAssertTrue(line.contains("Ray"))
        }

        QuipPicker.shared.reset()
        let seasonalLine = QuipPicker.shared.statusLine(progress: 0.4, at: at, exerciseDay: false, salt: 5, kidMode: false, calendar: cal, seasonal: true)
        let ordinary = QuipPicker.shared.statusLine(progress: 0.4, at: at, exerciseDay: false, salt: 5, kidMode: false, calendar: cal, seasonal: false)
        XCTAssertTrue(halloween.contains(seasonalLine))
        XCTAssertNotEqual(seasonalLine, ordinary)
        XCTAssertTrue(hidden.contains(ordinary))
    }

    func testSeasonalFactDoesNotAdvanceTheYearRoundIndex() {
        let d = defaults("rayna-season-facts")
        let extras = RaynaExtras(defaults: d)
        XCTAssertTrue(extras.rayFactsOn)
        let first = extras.factForMilestone(progress: 0.25, seasonal: true)
        XCTAssertEqual(first?.text, RayFacts.halloween[0].text)
        XCTAssertEqual(extras.factsUnlocked, 0)
        XCTAssertEqual(extras.halloweenFactsShown, 1)
        extras.rayFactsOn = false
        XCTAssertNil(extras.factForMilestone(progress: 0.5, seasonal: true))
        XCTAssertEqual(extras.halloweenFactsShown, 1)
        extras.rayFactsOn = true
        extras.halloweenFactsShown = RayFacts.halloween.count
        d.set("1999-01-01", forKey: "factMilestoneDay")
        let ordinary = extras.factForMilestone(progress: 0.25, seasonal: true)
        XCTAssertEqual(extras.factsUnlocked, 1)
        XCTAssertEqual(ordinary?.text, RayFacts.all[0].text)
        XCTAssertEqual(extras.halloweenFactsShown, RayFacts.halloween.count)
    }

    func testLittleTreatsCapUndoAndTheFactStaysIndependent() {
        XCTAssertEqual(SeasonTreats.dailyCap, 6)
        var last: SeasonBeat?
        var seen = Set<SeasonBeat>()
        for i in 0..<6 {
            let beat = SeasonTreats.nextBeat(count: i, last: last, draw: 0)
            XCTAssertNotNil(beat)
            if let last, let beat { XCTAssertNotEqual(beat, last) }
            seen.insert(beat!)
            last = beat
        }
        XCTAssertNil(SeasonTreats.nextBeat(count: 6, last: last, draw: 1))
        XCTAssertGreaterThan(seen.count, 1)

        let d = defaults("rayna-season-treats")
        let london = calendar("Europe/London")
        let now = date(london, 2026, 10, 20, 15)
        // Force the cape on for this suite by writing the opt-out key off inside the window.
        // isShowing reads the clock, so the test date has to be inside the automatic window.
        let extras = RaynaExtras(defaults: d)
        var beats: [SeasonBeat] = []
        for _ in 0..<6 {
            let treat = extras.takeLittleTreat(now: now, draw: 0, calendar: london)
            XCTAssertNotNil(treat)
            beats.append(treat!.beat)
        }
        XCTAssertNil(extras.takeLittleTreat(now: now, draw: 0, calendar: london))
        let count = d.integer(forKey: "treatCount")
        extras.rewindFactMilestone(progress: 0, now: now)
        extras.clearTreatLine()
        XCTAssertEqual(d.integer(forKey: "treatCount"), count)
        XCTAssertEqual(beats.count, 6)
        XCTAssertEqual(Set(beats).count, SeasonBeat.allCases.count)

        d.set(0, forKey: "factMilestone")
        let fact = extras.factForMilestone(progress: 0.25, now: now, seasonal: true)
        XCTAssertNotNil(fact)
        XCTAssertEqual(d.integer(forKey: "treatCount"), count, "a fact does not spend a little treat")
    }
}
