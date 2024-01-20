import Foundation
import os.log

// log stream --info --predicate 'subsystem == "com.inhill.flextime"'
let loggerSubsystem = Bundle.main.bundleIdentifier ?? "com.inhill.flextime"
let logger = Logger(subsystem: loggerSubsystem, category: "daemon")
 
let localISOFormatter = ISO8601DateFormatter()
localISOFormatter.timeZone = TimeZone.current

let interval: UInt32 = 60

func getProductName() -> String {
    return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Flextime"
}

func getProductVersion() -> String {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.15.0"
}

func getProductBuildNumber() -> String {
    return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
}

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
        
    } else {
        // Write to an existing file
        do {
            try data.write(to: last_path!)
        } catch {
            logger.notice("Error writing to \(last_path!.lastPathComponent, privacy: .public), retrying...")
            
            let path = try getPath()
            
            // This means that we just wrote duplicate data to a second file.  The
            // first file contains some of the same data.  But this is something that
            // the client is expected to handle and is a very rare error case.
            try data.write(to: path)

            last_path = path

            logger.notice("Retry successful to \(last_path!.lastPathComponent, privacy: .public)")
        }

        if last_flush! < Date().addingTimeInterval(-60 * 60 * 1) {
            logger.info("Wrote \(measurements.measurements.count) measurements to \(last_path!.lastPathComponent, privacy: .public)")

            // Create a new file for subsequent writes so that we do not create big files
            last_flush = nil
            last_path = nil
            
            measurements.measurements.removeAll()
        }
    }
}

var last_flush: Date? = nil
var last_path: URL? = nil

var measurements = Measurements()
measurements.interval = interval
measurements.zone = TimeZone.current.identifier

logger.info("\(getProductName(), privacy: .public) daemon \(getProductVersion(), privacy: .public) started")
print("\(getProductName()) daemon \(getProductVersion()) started (log subsystem: \(loggerSubsystem))")

let dispatchGroup = DispatchGroup()

func shutdown() {
    try! flushMeasurements()
    dispatchGroup.leave()

    logger.info("\(getProductName(), privacy: .public) daemon \(getProductVersion(), privacy: .public) terminated")

    exit(EXIT_SUCCESS)
}

// When running in launchd, we get a SIGTERM before a SIGKILL
// https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/Lifecycle.html
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

let signalIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signalIntSource.setEventHandler { shutdown() }
signalIntSource.resume()

let signalTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
signalTermSource.setEventHandler { shutdown() }
signalTermSource.resume()

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

            // We want to create measurements as close to the minute as possble.  The
            // reason is that when the user runs a client to inspect working hours,
            // we want the end time to match the clock.  Since we typically resolve
            // down to a minute, we want each measurement _and_ flush to disk to
            // happen _just_ as a new minute on the clock starts.
            let next = Date().addingTimeInterval(TimeInterval(interval))
            let nearestMinuteSince1970 = (next.timeIntervalSince1970 / 60).rounded(.toNearestOrAwayFromZero) * 60
            let nearestMinute = Date(timeIntervalSince1970: nearestMinuteSince1970)
                
            Thread.sleep(until: nearestMinute)
        }
    } catch {
        print(error)
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
