//
//  MeasurementsView.swift
//  flextime.app
//
//  Created by Martin Altenstedt on 2021-06-20.
//

import SwiftUI

struct MeasurementsView: View {
    @ObservedObject var data: MeasurementsWrapper
    
    var body: some View {
        List(data.days) { item in
            HStack{
                Text("Sunday, June 20th")
                Text("08:13")
                Text("04:13")
            }
        }.onAppear() {
            data.fetchDays()
        }
    }
}

struct MeasurementsView_Previews: PreviewProvider {
    static var previews: some View {
        MeasurementsView(data: MeasurementsWrapper())
    }
}
