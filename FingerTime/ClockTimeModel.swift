//
//  ClockTimeModel.swift
//  FingerTime
//
//  Created by Codex on 5/3/26.
//

import Foundation
import Observation

@MainActor @Observable
final class ClockTimeModel {
    var isFreePlayMode = false {
        didSet {
            guard oldValue != isFreePlayMode else { return }
            manualAnchor = nil
            if isFreePlayMode {
                setBackground(for: ClockTime(hour: 0, minute: 0, second: 0))
            }
        }
    }

    // Observable: only triggers re-render when background actually rotates (hourly)
    private(set) var currentBackground: NASASpaceBackground

    // Not observable: struct mutations happen on every tick() but only currentBackground notifies
    @ObservationIgnored private var backgroundRotator: SpaceBackgroundRotator

    private let autoReturnDelay: TimeInterval
    private let calendar: Calendar
    // Observable: drag updates this → TimelineView reacts immediately without waiting for next tick
    private var manualAnchor: (time: ClockTime, date: Date)?

    init(
        now: Date = Date(),
        autoReturnDelay: TimeInterval = 60,
        calendar: Calendar = .current,
        backgrounds: [NASASpaceBackground] = NASASpaceBackground.curated,
        shuffleBackgrounds: Bool = true
    ) {
        self.autoReturnDelay = autoReturnDelay
        self.calendar = calendar
        let initialTime = ClockTime(date: now, calendar: calendar)
        backgroundRotator = SpaceBackgroundRotator(
            backgrounds: shuffleBackgrounds ? backgrounds.shuffled() : backgrounds,
            initialTime: initialTime
        )
        currentBackground = backgroundRotator.current
    }

    /// Pure time computation — no side effects. Called from TimelineView content on each frame.
    func timeAt(_ date: Date) -> ClockTime {
        if isFreePlayMode {
            return manualAnchor?.time ?? ClockTime(hour: 0, minute: 0, second: 0)
        }
        if let manualAnchor {
            let elapsed = date.timeIntervalSince(manualAnchor.date)
            if elapsed >= autoReturnDelay {
                return ClockTime(date: date, calendar: calendar)
            }
            return manualAnchor.time.adding(seconds: elapsed)
        }
        return ClockTime(date: date, calendar: calendar)
    }

    /// Called at 1 Hz for state maintenance: expiring the manual anchor and rotating the background.
    func tick(now: Date = Date()) {
        guard !isFreePlayMode else { return }
        if let anchor = manualAnchor, now.timeIntervalSince(anchor.date) >= autoReturnDelay {
            manualAnchor = nil
        }
        setBackground(for: timeAt(now))
    }

    func applyDragDelta(_ deltaDegrees: Double, to hand: ClockHand, now: Date = Date()) {
        let nextTime = ClockTimeMath.applyingDragDelta(deltaDegrees, to: hand, current: timeAt(now))
        // .distantPast sentinel: free-play anchors are never expired by tick()
        manualAnchor = isFreePlayMode ? (nextTime, .distantPast) : (nextTime, now)
        setBackground(for: nextTime)
    }

    private func setBackground(for time: ClockTime) {
        backgroundRotator.update(for: time)
        let newBackground = backgroundRotator.current
        if newBackground != currentBackground {
            currentBackground = newBackground
        }
    }
}
