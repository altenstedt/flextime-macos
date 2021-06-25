//
//  main.swift
//  flextime
//
//  Created by Martin Altenstedt on 2021-06-19.
//

import Foundation
import ArgumentParser

struct Options: ParsableArguments {
    @Flag(name: .shortAndLong, help: ArgumentHelp("Split weeks with a new line."))
    var splitWeeks = false

    @Option(name: .shortAndLong, help: "Idle limit in minutes.")
    var idle = 10.0

    @Flag(name: .shortAndLong, help: "Print version information and exit.")
    var version = false
}

// If you prefer writing in a "script" style, you can call `parseOrExit()` to
// parse a single `ParsableArguments` type from command-line arguments.
let options = Options.parseOrExit()

if (options.version) {
    print("\(getProductName()) \(getProductVersion())")
    exit(0)
}

var foo = [Measurement]()
let fixed = 60.0 * options.idle

func fetchDays() throws {
    let identifier = "com.inhill.flextime" // Coordinated with Flextime daemon
    
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(identifier)/measurements/")

    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

    let filtered = files.filter{ $0.pathExtension == "bin" }
    
    for file in filtered {
        let data = try Data(contentsOf: file)

        let measurements = try Measurements(serializedData: data)
        
        foo.append(contentsOf: measurements.measurements)
    }
    
    foo.sort {
        return $0.timestamp < $1.timestamp
    }
    
    var current = Date(timeIntervalSince1970: TimeInterval(foo.first!.timestamp))
    var start = current
    var work = TimeInterval(0.0)
    
    for (index, measurement) in foo.enumerated() {
        let date = Date(timeIntervalSince1970: TimeInterval(measurement.timestamp))

        if (Calendar.current.compare(date, to: current, toGranularity: .day) != .orderedSame) {
            // Different day
            
            // start points to the first measurement on the previous day.
            // current points to the last measurement on the previous day.
            printDay(start: start, end: current, work: work)
            
            start = date // New day
            work = 0.0
            
            if (Calendar.current.compare(date, to: current, toGranularity: .weekOfYear) != .orderedSame) {
                if (options.splitWeeks) {
                    print() // newline
                }
            }
        } else {
            // Same day
            if (index > 0) {
                let previousStopTime = TimeInterval(foo[index - 1].timestamp)
                let stopTime = TimeInterval(measurement.timestamp)

                if (stopTime - previousStopTime < fixed) {
                  work += stopTime - previousStopTime;
                }
            }
        }
        
        if (index == foo.endIndex - 1) {
            // Last item
            printDay(start: start, end: date, work: work)
        }
        
        current = date;
    }
}

func printDay(start: Date, end: Date, work: TimeInterval) {
    let dateOptions: ISO8601DateFormatter.Options = [.withFullDate ]
    
    let durationFormatter = DateComponentsFormatter()
    durationFormatter.allowedUnits = [.hour, .minute]
    durationFormatter.zeroFormattingBehavior = .pad
    durationFormatter.unitsStyle = .positional

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"

    let dayFormatter = DateFormatter()
    dayFormatter.setLocalizedDateFormatFromTemplate("EEEE")

    let dateString = ISO8601DateFormatter.string(from: start, timeZone: TimeZone.current, formatOptions: dateOptions)

    let startTimeString = timeFormatter.string(for: start)!
    let stopTimeString = timeFormatter.string(for: end)!

    let diff = end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate

    let timeString = durationFormatter.string(from: diff) ?? ""
    let workString = durationFormatter.string(from: work) ?? ""
    
    let dayString = dayFormatter.string(from: start)
    let week = Calendar.init(identifier: .iso8601).component(.weekOfYear, from: start)

    print("\(dateString) \(startTimeString) — \(stopTimeString) \(timeString) | \(workString) w/\(week) \(dayString)")
}

func getProductName() -> String {
    return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Flextime"
}

func getProductVersion() -> String {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.14.0"
}

func getProductBuildNumber() -> String {
    return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
}

try fetchDays();

