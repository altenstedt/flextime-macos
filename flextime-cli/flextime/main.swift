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

    @Flag(name: .shortAndLong, help: "Log in to the Flextime online service.")
    var login = false
    
    @Option(name: .long, help: "Base URL for the login token service.")
    var tokenBaseUrl = "https://localhost:5000/"
}

struct DeviceAuthorizationResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: UInt32
    let interval: UInt32
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: UInt32
}

// If you prefer writing in a "script" style, you can call `parseOrExit()` to
// parse a single `ParsableArguments` type from command-line arguments.
let options = Options.parseOrExit()

if (options.version) {
    print("\(getProductName()) \(getProductVersion())")
    exit(0)
}

if (options.login) {
    let url = URL(string: "/connect/deviceauthorization", relativeTo: URL(string: options.tokenBaseUrl))

    let headers = ["Content-Type": "application/x-www-form-urlencoded"]

    var authorizationComponents = URLComponents()
    authorizationComponents.queryItems = [URLQueryItem(name: "client_id", value: "test")]

    var authorizationRequest = URLRequest(url: url!)
    authorizationRequest.httpMethod = "POST"
    authorizationRequest.allHTTPHeaderFields = headers
    authorizationRequest.httpBody = authorizationComponents.query?.data(using: .utf8)
    
    let semaphore = DispatchSemaphore(value: 0)

    let authorizationTask = deviceAuthorization() { authorizationResponse, _, _ in
        if let authorizationResponse = authorizationResponse {
            do {
                print("Use a web browser to open the page \(authorizationResponse.verificationUri) and enter the code \(authorizationResponse.userCode) to authenticate.")
                
                var done = false
                repeat {
                    let tokenTask = pollToken(deviceCode: authorizationResponse.deviceCode) { tokenResponse, foo, error in
                        if let tokenResponse = tokenResponse {
                            print("Access token \(tokenResponse.accessToken)")
                            semaphore.signal()
                            done = true
                        }
                    }
                    
                    tokenTask.resume()
                    
                    print("Sleep for \(authorizationResponse.interval)")
                    sleep(authorizationResponse.interval)
                } while !done
            }
        }
    }
    
        /*
    let authorizationTask = URLSession.shared.dataTask(with: authorizationRequest) { authorizationData, authorizationResponse, authorizationError in
        if let data = authorizationData {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let authorizationResponse = try decoder.decode(DeviceAuthorizationResponse.self, from: data)
                
                print("Use a web browser to open the page \(authorizationResponse.verificationUri) and enter the code \(authorizationResponse.userCode) to authenticate.")
                
                var pollComponents = URLComponents()
                pollComponents.queryItems = [
                    URLQueryItem(name: "client_id", value: "test"),
                    URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code"),
                    URLQueryItem(name: "device_code", value: authorizationResponse.deviceCode)
                ]

                var pollRequest = URLRequest(url: url!)
                pollRequest.httpMethod = "POST"
                pollRequest.allHTTPHeaderFields = headers
                pollRequest.httpBody = pollComponents.query?.data(using: .utf8)
                
                repeat {
                    let loopTask = URLSession.shared.dataTask(with: pollRequest) { loopData, loopResponse, loopError in
                        if let loopData = loopData {
                            print("Loop")
                        }
                    }
                    
                    loopTask.resume()
                    Thread.current.sleep(TimeInterval(authorizationResponse.interval))
                } while true
                
            } catch let error {
                print(error)
            }
        } else if let error = authorizationError {
            print("HTTP Request Failed \(error)")
        }
        
        semaphore.signal()
    }
 */
    
    authorizationTask.resume()

    semaphore.wait()
    exit(0)
}

func deviceAuthorization(completionHandler: @escaping (DeviceAuthorizationResponse?, URLResponse?, Error?) -> Void) -> URLSessionDataTask{
    let url = URL(string: "/connect/deviceauthorization", relativeTo: URL(string: options.tokenBaseUrl))

    let headers = ["Content-Type": "application/x-www-form-urlencoded"]

    var components = URLComponents()
    components.queryItems = [URLQueryItem(name: "client_id", value: "test")]

    var request = URLRequest(url: url!)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    request.httpBody = components.query?.data(using: .utf8)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let authorizationResponse = try decoder.decode(DeviceAuthorizationResponse.self, from: data)
                
                return completionHandler(authorizationResponse, response, error)
            } catch let error {
                return completionHandler(nil, response, error)
            }
        } else if let error = error {
            return completionHandler(nil, response, error)
        }
    }
    
    return task
}

func pollToken(deviceCode: String, completionHandler: @escaping (TokenResponse?, URLResponse?, Error?) -> Void) -> URLSessionDataTask{
    let url = URL(string: "/connect/token", relativeTo: URL(string: options.tokenBaseUrl))

    let headers = ["Content-Type": "application/x-www-form-urlencoded"]

    var components = URLComponents()
    components.queryItems = [
        URLQueryItem(name: "client_id", value: "test"),
        URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code"),
        URLQueryItem(name: "device_code", value: deviceCode)
    ]

    var request = URLRequest(url: url!)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    request.httpBody = components.query?.data(using: .utf8)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
                
                return completionHandler(tokenResponse, response, error)
            } catch let error {
                return completionHandler(nil, response, error)
            }
        } else if let error = error {
            return completionHandler(nil, response, error)
        }
    }
    
    return task
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

