//
//  main.swift
//  flextime
//
//  Created by Martin Altenstedt on 2021-06-19.
//

import Foundation

let localISOFormatter = ISO8601DateFormatter()
localISOFormatter.timeZone = TimeZone.current

let interval: UInt32 = 60

func createMeasurement(idle: CFTimeInterval) -> Measurement {
    let now = Date()

    var measurement = Measurement()
    measurement.idle = UInt32(idle)
    measurement.kind = Measurement.Kind.measurement
    measurement.timestamp = UInt32(now.timeIntervalSince1970)
    
    return measurement
}

func getPath() throws -> URL {
    let options: ISO8601DateFormatter.Options = [.withFullDate, .withTime, .withTimeZone]
    let fileName = ISO8601DateFormatter.string(from: Date(), timeZone: TimeZone.init(identifier: "UTC")!, formatOptions: options)
    
    let identifier = Bundle.main.bundleIdentifier ?? "com.inhill.flextime"
    
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(identifier)/measurements/")
    
    try FileManager.default.createDirectory (at: directory, withIntermediateDirectories: true, attributes: nil)

    return directory.appendingPathComponent("\(fileName).bin")
}

func flushMeasurements() throws {
    if (measurements.measurements.count == 0) {
        return
    }

    let data = try measurements.serializedData()
    
    if last_flush == nil || last_path == nil {
        // Write to a new file
        let path = try getPath()

        try data.write(to: path)
        
        last_path = path
        last_flush = Date()
        
        print("Flushed \(measurements.measurements.count) measurements to \(path.lastPathComponent)")
    } else {
        // Write to an existing file
        do {
            try data.write(to: last_path!)
        } catch {
            print("Error writing to path \(last_path!.lastPathComponent), retrying with a new file...")
            
            let path = try getPath()
            
            try data.write(to: path)
            
            last_path = path
        }

        print("Flushed \(measurements.measurements.count) measurements to \(last_path!.lastPathComponent)")

        if last_flush! < Date().addingTimeInterval(-60 * 60 * 1) {
            // Create a new file for subsequent writes so that we do not create big files
            last_flush = nil
            last_path = nil
            
            measurements.measurements.removeAll()

            print("Clear measurements for new file")
        }
    }
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

var last_flush: Date? = nil
var last_path: URL? = nil

var measurements = Measurements()
measurements.interval = interval
measurements.zone = TimeZone.current.identifier

print("\(getProductName()) daemon \(getProductVersion()) started")
let dispatchGroup = DispatchGroup()

signal(SIGINT, SIG_IGN)

let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signalSource.setEventHandler {
    try! flushMeasurements()
    dispatchGroup.leave()
    
    print("\(getProductName()) daemon \(getProductVersion()) terminated")

    exit(EXIT_SUCCESS)
}
signalSource.resume()

dispatchGroup.enter()

DispatchQueue.global(qos: .userInitiated).async {
    do {
        while(true) {
            let anyInputEventType = CGEventType(rawValue: ~0)!
            let secondsSinceLastEventType = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.combinedSessionState, eventType: anyInputEventType)

            // The time between measurement is not perfect, so be on the safe side,
            // we compare to a somewhat larger value.
            let active = secondsSinceLastEventType < Double(interval) * 1.2;
            
            if (active) {
                let measurement = createMeasurement(idle: secondsSinceLastEventType);
                
                measurements.measurements.append(measurement)
                
                try flushMeasurements()
            }

            sleep(interval)
        }
    } catch {
        print(error)
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
