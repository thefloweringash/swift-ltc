//
//  ContentView.swift
//  SwiftUILTC
//
//  Created by Andrew Childs on 2025/03/15.
//

import libltc
import SwiftLTC
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var dropTargetted: Bool = false

    @State var firstTimecode: (LTCFrameExt, SMPTETimecode)? = nil

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            if let firstTimecode {
                Text(verbatim: timecodeToString(frame: firstTimecode.0, stime: firstTimecode.1))
            }
        }
        .padding()
        .onDrop(of: [.wav], isTargeted: $dropTargetted) { items in
            for item in items {
                if item.hasItemConformingToTypeIdentifier(UTType.wav.identifier) {
                    Task { @MainActor in
                        let url = try! await item.loadItem(forTypeIdentifier: UTType.wav.identifier) as! URL
                        var decoder = LTCDecoder()!
                        try! decoder.decode(fromURL: url) { frame in
                            let stime = frame.toSMTPETimecode(flags: .useDate)
                            firstTimecode = (frame, stime)
                            return false
                        }
                    }
                }
            }

            return false
        }
    }

    func timecodeToString(frame: LTCFrameExt, stime: SMPTETimecode) -> String {
        String(format: "%02d:%02d:%02d%@%02d | %8lld %8lld%@",
               stime.hours,
               stime.mins,
               stime.secs,
               (frame.ltc.dfbit != 0) ? "." : ":",
               stime.frame,
               frame.off_start,
               frame.off_end,
               (frame.reverse != 0) ? " R" : "  ")
    }
}

#Preview {
    ContentView()
}
