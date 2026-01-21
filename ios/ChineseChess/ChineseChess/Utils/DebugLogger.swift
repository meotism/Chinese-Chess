//
//  DebugLogger.swift
//  ChineseChess
//
//  Debug logging utility that only logs in DEBUG builds.
//  This prevents sensitive information from leaking in production.
//

import Foundation
import os.log

/// A debug-only logger that automatically strips logging in release builds.
///
/// Usage:
/// ```swift
/// DebugLog.info("User logged in")
/// DebugLog.error("Failed to connect", error)
/// DebugLog.warning("Low memory")
/// ```
enum DebugLog {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.xiangqi.ChineseChess"
    private static let logger = Logger(subsystem: subsystem, category: "Debug")

    /// Log an informational message (DEBUG builds only)
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        logger.info("[\(filename):\(line)] \(message)")
        #endif
    }

    /// Log a warning message (DEBUG builds only)
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        logger.warning("[\(filename):\(line)] \(message)")
        #endif
    }

    /// Log an error message (DEBUG builds only)
    static func error(_ message: String, _ error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        if let error = error {
            logger.error("[\(filename):\(line)] \(message): \(error.localizedDescription)")
        } else {
            logger.error("[\(filename):\(line)] \(message)")
        }
        #endif
    }

    /// Log network-related messages (DEBUG builds only)
    static func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        logger.debug("[Network][\(filename):\(line)] \(message)")
        #endif
    }

    /// Log game-related messages (DEBUG builds only)
    static func game(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        logger.debug("[Game][\(filename):\(line)] \(message)")
        #endif
    }
}
