//
//  PhotoFlowDebug.swift
//  FingerTime
//
//  Created by Codex on 5/4/26.
//

import Foundation
import OSLog

enum PhotoFlowDebug {
    private static let logger = Logger(subsystem: "com.oozoofrog.macos.FingerTime", category: "PhotoFlow")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        console(message)
    }

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        if ProcessInfo.processInfo.environment["FINGERTIME_VERBOSE_PHOTO_DEBUG"] == "1" {
            console("DEBUG: \(message)")
        }
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        console("ERROR: \(message)")
    }

    private static func console(_ message: String) {
        #if DEBUG
        print("🕰️ [PhotoFlow] \(message)")
        fflush(stdout)
        #endif
    }
}
