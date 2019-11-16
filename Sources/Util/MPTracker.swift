//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Amplitude_iOS
import Mixpanel

typealias Value = MixpanelType

class MPTracker {
    static let shared = MPTracker()

    private var screens = [ Screen ]()
    private var pending = [ String: Date ]()

    private init() {
        // Heap
        Heap.setAppId( "" )
        Heap.startEVPairing()

        // Amplitude
        Amplitude.instance().initializeApiKey( "" )

        // Mixpanel
        Mixpanel.initialize( token: "" )
    }

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        self.event( file: file, line: line, function: function, dso: dso,
                    named: "\(productName) #launch", [ "version": productVersion, "build": productBuild ] )
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String) -> Screen {
        let screen = Screen( name: name, tracker: self )
        self.screens.append( screen )

        screen.begin()
        screen.event( file: file, line: line, function: function, dso: dso, event: "open" )

        return screen
    }

    func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String) {
        dbg( file: file, line: line, function: function, dso: dso, "> %@", name )

        self.pending[name] = Date()
        Mixpanel.mainInstance().time( event: name )
    }

    func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String, _ parameters: [String: Value] = [:]) {
        var eventParameters = parameters
        if let started = self.pending.removeValue( forKey: name ) {
            eventParameters["duration"] = Date().timeIntervalSince( started )
        }

        if eventParameters.isEmpty {
            dbg( file: file, line: line, function: function, dso: dso, "@ %@", name )
        }
        else {
            dbg( file: file, line: line, function: function, dso: dso, "@ %@: [%@]", name, eventParameters )
        }

        Heap.track( name, withProperties: eventParameters )
        Amplitude.instance().logEvent( name, withEventProperties: eventParameters )
        Mixpanel.mainInstance().track( event: name, properties: eventParameters )
    }

    class Screen {
        let name: String
        private let tracker: MPTracker

        init(name: String, tracker: MPTracker) {
            self.name = name
            self.tracker = tracker
        }

        fileprivate func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            self.tracker.begin( file: file, line: line, function: function, dso: dso, named: self.name )
        }

        func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String) {
            self.tracker.begin( file: file, line: line, function: function, dso: dso, named: "\(self.name) #\(event)" )
        }

        func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String) {
            self.tracker.event( file: file, line: line, function: function, dso: dso, named: "\(self.name) #\(event)" )
        }

        func dismiss(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            self.event( file: file, line: line, function: function, dso: dso, event: "close" )
            self.tracker.event( file: file, line: line, function: function, dso: dso, named: self.name )

            self.tracker.screens.removeAll { $0 === self }
        }
    }
}
