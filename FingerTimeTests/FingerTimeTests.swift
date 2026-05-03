//
//  FingerTimeTests.swift
//  FingerTimeTests
//
//  Created by oozoofrog on 5/3/26.
//

import Foundation
import Testing
@testable import FingerTime

struct FingerTimeTests {

    @Test func clockAnglesIncludeRealAnalogHandCoupling() {
        let time = ClockTime(hour: 3, minute: 15, second: 30)
        let angles = ClockTimeMath.angles(for: time)

        #expect(angles.hour == 97.75)
        #expect(angles.minute == 93)
        #expect(angles.second == 180)
    }

    @Test func minuteHandFullTurnMovesHourForward() {
        let start = ClockTime(hour: 3, minute: 0, second: 0)

        let result = ClockTimeMath.applyingDragDelta(360, to: .minute, current: start)

        #expect(result.hour == 4)
        #expect(result.minute == 0)
        #expect(ClockTimeMath.angles(for: result).hour == 120)
    }

    @Test func secondHandFullTurnMovesMinuteForward() {
        let start = ClockTime(hour: 12, minute: 0, second: 0)

        let result = ClockTimeMath.applyingDragDelta(360, to: .second, current: start)

        #expect(result.hour == 12)
        #expect(result.minute == 1)
        #expect(ClockTimeMath.angles(for: result).minute == 6)
    }

    @Test func backgroundAdvancesWhenDisplayedTimeCrossesAnHour() {
        let backgrounds = [
            NASASpaceBackground(title: "One", credit: "NASA", url: URL(string: "https://example.com/one.jpg")!),
            NASASpaceBackground(title: "Two", credit: "NASA", url: URL(string: "https://example.com/two.jpg")!)
        ]
        var rotator = SpaceBackgroundRotator(backgrounds: backgrounds, initialTime: ClockTime(hour: 1, minute: 59, second: 59))

        rotator.update(for: ClockTime(hour: 2, minute: 0, second: 0))
        rotator.update(for: ClockTime(hour: 2, minute: 10, second: 0))

        #expect(rotator.current.title == "Two")
    }

    @Test func backgroundAdvancesProportionallyForMultiHourJump() {
        let backgrounds = [
            NASASpaceBackground(title: "A", credit: "NASA", url: URL(string: "https://example.com/a.jpg")!),
            NASASpaceBackground(title: "B", credit: "NASA", url: URL(string: "https://example.com/b.jpg")!),
            NASASpaceBackground(title: "C", credit: "NASA", url: URL(string: "https://example.com/c.jpg")!),
            NASASpaceBackground(title: "D", credit: "NASA", url: URL(string: "https://example.com/d.jpg")!)
        ]
        var rotator = SpaceBackgroundRotator(backgrounds: backgrounds, initialTime: ClockTime(hour: 1, minute: 0, second: 0))

        rotator.update(for: ClockTime(hour: 4, minute: 0, second: 0))
        #expect(rotator.currentIndex == 3)

        rotator.update(for: ClockTime(hour: 2, minute: 0, second: 0))
        #expect(rotator.currentIndex == 1)
    }

    @MainActor
    @Test func manualTimeReturnsToRealTimeAfterDelay() {
        let base = Date(timeIntervalSince1970: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let model = ClockTimeModel(
            now: base,
            autoReturnDelay: 60,
            calendar: calendar,
            shuffleBackgrounds: false
        )

        model.applyDragDelta(360, to: .minute, now: base)
        model.tick(now: base.addingTimeInterval(30))

        #expect(model.displayedTime.hour == 1)

        model.tick(now: base.addingTimeInterval(61))

        #expect(model.displayedTime.hour == ClockTime(date: base.addingTimeInterval(61), calendar: calendar).hour)
    }

    @MainActor
    @Test func enteringFreePlayModeResetsToStoppedTwelveOClock() {
        let base = Date(timeIntervalSince1970: 3 * 3_600 + 15 * 60 + 30)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let model = ClockTimeModel(
            now: base,
            calendar: calendar,
            shuffleBackgrounds: false
        )

        model.isFreePlayMode = true
        model.tick(now: base.addingTimeInterval(42))

        #expect(model.displayedTime.secondsSinceMidnight == 0)
        #expect(ClockTimeMath.angles(for: model.displayedTime) == ClockAngles(hour: 0, minute: 0, second: 0))
    }

    @MainActor
    @Test func freePlayDragChangesTimeWithoutAutoTicking() {
        let base = Date(timeIntervalSince1970: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let model = ClockTimeModel(
            now: base,
            calendar: calendar,
            shuffleBackgrounds: false
        )

        model.isFreePlayMode = true
        model.applyDragDelta(360, to: .minute, now: base)
        model.tick(now: base.addingTimeInterval(30))

        #expect(model.displayedTime.secondsSinceMidnight == 3_600)
    }
}
