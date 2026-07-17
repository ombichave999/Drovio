//
//  Log.swift
//  Drovio
//
//  Structured logging via os.Logger. Categories per subsystem area.
//

import os

enum Log {
    private static let subsystem = "com.drovio.Drovio"

    static let app       = Logger(subsystem: subsystem, category: "app")
    static let engine    = Logger(subsystem: subsystem, category: "engine")
    static let toolbox   = Logger(subsystem: subsystem, category: "toolbox")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let history   = Logger(subsystem: subsystem, category: "history")
    static let settings  = Logger(subsystem: subsystem, category: "settings")
}
