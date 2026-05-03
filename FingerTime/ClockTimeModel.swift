//
//  ClockTimeModel.swift
//  FingerTime
//
//  Created by Codex on 5/3/26.
//

import Combine
import Foundation

@MainActor
final class ClockTimeModel: ObservableObject {
    @Published private(set) var displayedTime: ClockTime
    @Published var isFreePlayMode = false
    @Published private(set) var backgroundRotator: SpaceBackgroundRotator

    private let autoReturnDelay: TimeInterval
    private let calendar: Calendar
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
        displayedTime = initialTime
        backgroundRotator = SpaceBackgroundRotator(
            backgrounds: shuffleBackgrounds ? backgrounds.shuffled() : backgrounds,
            initialTime: initialTime
        )
    }

    var currentBackground: NASASpaceBackground {
        backgroundRotator.current
    }

    func tick(now: Date = Date()) {
        let nextTime: ClockTime
        if let manualAnchor {
            let elapsed = now.timeIntervalSince(manualAnchor.date)
            if !isFreePlayMode && elapsed >= autoReturnDelay {
                self.manualAnchor = nil
                nextTime = ClockTime(date: now, calendar: calendar)
            } else {
                nextTime = manualAnchor.time.adding(seconds: elapsed)
            }
        } else {
            nextTime = ClockTime(date: now, calendar: calendar)
        }

        displayedTime = nextTime
        backgroundRotator.update(for: nextTime)
    }

    func applyDragDelta(_ deltaDegrees: Double, to hand: ClockHand, now: Date = Date()) {
        let nextTime = ClockTimeMath.applyingDragDelta(deltaDegrees, to: hand, current: displayedTime)
        displayedTime = nextTime
        manualAnchor = (nextTime, now)
        backgroundRotator.update(for: nextTime)
    }
}
