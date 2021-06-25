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
let flush_interval = 3000

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
                
                if (measurements.measurements.last!.timestamp - measurements.measurements.first!.timestamp > flush_interval) {
                    try flushMeasurements()
                }
            }

            sleep(interval)
        }
    } catch {
        print(error)
        exit(EXIT_FAILURE)
    }
}

dispatchMain()

func createMeasurement(idle: CFTimeInterval) -> Measurement {
    let now = Date()

    var measurement = Measurement()
    measurement.idle = UInt32(idle)
    measurement.kind = Measurement.Kind.measurement
    measurement.timestamp = UInt32(now.timeIntervalSince1970)
    
    return measurement
}

func flushMeasurements() throws {
    let data = try measurements.serializedData()
    
    let options: ISO8601DateFormatter.Options = [.withFullDate, .withTime, .withTimeZone]
    let fileName = ISO8601DateFormatter.string(from: Date(), timeZone: TimeZone.init(identifier: "UTC")!, formatOptions: options)
    
    let identifier = Bundle.main.bundleIdentifier ?? "com.inhill.flextime"
    
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(identifier)/measurements/")
    
    try FileManager.default.createDirectory (at: directory, withIntermediateDirectories: true, attributes: nil)

    let path = directory.appendingPathComponent("\(fileName).bin")
    try data.write(to: path)
    
    print("Flushed measurements to \(fileName.description).bin")
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
