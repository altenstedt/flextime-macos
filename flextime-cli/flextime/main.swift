//
//  main.swift
//  flextime
//
//  Created by Martin Altenstedt on 2021-06-19.
//

import Foundation

var foo = [Measurement]()
let fixed = 60.0 * 10

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
                print() // newline
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

try fetchDays();

