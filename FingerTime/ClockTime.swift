//
//  ClockTime.swift
//  FingerTime
//
//  Created by Codex on 5/3/26.
//

import CoreGraphics
import Foundation

enum ClockHand: CaseIterable {
    case hour
    case minute
    case second
}

struct ClockAngles: Equatable {
    let hour: Double
    let minute: Double
    let second: Double
}

struct ClockTime: Equatable, Sendable {
    private static let secondsPerDay: TimeInterval = 86_400

    let secondsSinceMidnight: TimeInterval

    init(secondsSinceMidnight: TimeInterval) {
        let normalized = secondsSinceMidnight.truncatingRemainder(dividingBy: Self.secondsPerDay)
        self.secondsSinceMidnight = normalized >= 0 ? normalized : normalized + Self.secondsPerDay
    }

    init(hour: Int, minute: Int, second: Int) {
        self.init(secondsSinceMidnight: TimeInterval(hour * 3_600 + minute * 60 + second))
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let wholeSeconds = TimeInterval((components.hour ?? 0) * 3_600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
        let fractionalSeconds = TimeInterval(components.nanosecond ?? 0) / 1_000_000_000
        self.init(secondsSinceMidnight: wholeSeconds + fractionalSeconds)
    }

    var hour: Int {
        Int(secondsSinceMidnight / 3_600)
    }

    var minute: Int {
        Int(secondsSinceMidnight / 60) % 60
    }

    var second: Int {
        Int(secondsSinceMidnight) % 60
    }

    var hourMarker: Int {
        Int(secondsSinceMidnight / 3_600)
    }

    func adding(seconds: TimeInterval) -> ClockTime {
        ClockTime(secondsSinceMidnight: secondsSinceMidnight + seconds)
    }
}

enum ClockTimeMath {
    static func angles(for time: ClockTime) -> ClockAngles {
        let seconds = time.secondsSinceMidnight
        let hourRemainder = seconds.truncatingRemainder(dividingBy: 43_200)
        let minuteRemainder = seconds.truncatingRemainder(dividingBy: 3_600)
        let secondRemainder = seconds.truncatingRemainder(dividingBy: 60)

        return ClockAngles(
            hour: roundedDegrees(hourRemainder / 43_200 * 360),
            minute: roundedDegrees(minuteRemainder / 3_600 * 360),
            second: roundedDegrees(secondRemainder / 60 * 360)
        )
    }

    static func applyingDragDelta(_ deltaDegrees: Double, to hand: ClockHand, current: ClockTime) -> ClockTime {
        let secondsPerFullTurn: TimeInterval
        switch hand {
        case .hour:
            secondsPerFullTurn = 43_200
        case .minute:
            secondsPerFullTurn = 3_600
        case .second:
            secondsPerFullTurn = 60
        }

        return current.adding(seconds: deltaDegrees / 360 * secondsPerFullTurn)
    }

    static func shortestDeltaDegrees(from previous: Double, to current: Double) -> Double {
        var delta = current - previous
        while delta > 180 {
            delta -= 360
        }
        while delta < -180 {
            delta += 360
        }
        return delta
    }

    static func angle(for location: CGPoint, in size: CGSize) -> Double {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radians = atan2(dx, -dy)
        let degrees = radians * 180 / .pi
        return degrees >= 0 ? degrees : degrees + 360
    }

    static func angularDistance(_ lhs: Double, _ rhs: Double) -> Double {
        abs(shortestDeltaDegrees(from: lhs, to: rhs))
    }

    private static func roundedDegrees(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }
}
