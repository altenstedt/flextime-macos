//
//  main.swift
//  flextime
//
//  Created by Martin Altenstedt on 2021-06-19.
//

import Foundation

var foo = [Measurement]()

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
    
    for (index, measurement) in foo.enumerated() {
        let date = Date(timeIntervalSince1970: TimeInterval(measurement.timestamp))

        if (Calendar.current.compare(date, to: current, toGranularity: .day) != .orderedSame) {
            // start points to the first measurement on the previous day.
            // current points to the last measurement on the previous day.
            printDay(start: start, end: current)
            
            start = date // New day
            
            if (Calendar.current.compare(date, to: current, toGranularity: .weekOfYear) != .orderedSame) {
                print() // newline
            }
        }
        
        if (index == foo.endIndex - 1) {
            // Last item
            printDay(start: start, end: date)
        }
        
        current = date;
    }
}

func printDay(start: Date, end: Date) {
    let dateOptions: ISO8601DateFormatter.Options = [.withFullDate]
    let timeOptions: ISO8601DateFormatter.Options = [.withColonSeparatorInTime, .withTime]
    
    let timeFormatter = DateComponentsFormatter()
    timeFormatter.allowedUnits = [.hour, .minute]
    timeFormatter.zeroFormattingBehavior = .pad
    timeFormatter.unitsStyle = .positional

    let dateString = ISO8601DateFormatter.string(from: start, timeZone: TimeZone.current, formatOptions: dateOptions)

    let startTimeString = ISO8601DateFormatter.string(from: start, timeZone: TimeZone.current, formatOptions: timeOptions)
    let stopTimeString = ISO8601DateFormatter.string(from: end, timeZone: TimeZone.current, formatOptions: timeOptions)

    let diff = end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate

    let timeString = timeFormatter.string(from: diff) ?? ""
    
    print("\(dateString) \(startTimeString) \(stopTimeString) \(timeString)")

}

try fetchDays();

