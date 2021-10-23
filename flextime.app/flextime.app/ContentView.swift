//
//  ContentView.swift
//  flextime.app
//
//  Created by Martin Altenstedt on 2021-06-20.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            MapView()
                 .ignoresSafeArea(edges: .top)
                 .frame(height: 200)

            MeasurementsView(data: MeasurementsWrapper())
            
            Text(getProductName())
                .padding()
                .font(.title)

            Text(getProductVersion())
                .padding()
            
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
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
