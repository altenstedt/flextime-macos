//
//  summary.swift
//  flextime.app
//
//  Created by Martin Altenstedt on 2021-06-20.
//

import Foundation

struct Day: Identifiable {
    let id = UUID()
}

class MeasurementsWrapper: ObservableObject {
    @Published var days: [Day] = []

    func fetchDays() {
        let identifier = "com.inhill.flextime" // Coordinated with Flextime daemon
        
        let foo = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(identifier)/measurements/")

        let files = try! FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

        let mp3Files = files.filter{ $0.pathExtension == "bin" }
        print("mp3 urls:",mp3Files)

        let mp3FileNames = mp3Files.map{ $0.deletingPathExtension().lastPathComponent }
           
            // let data = try Data(contentsOf: file)

            // let measurements = try Measurements(serializedData: data)

        self.days = []
    }

}
