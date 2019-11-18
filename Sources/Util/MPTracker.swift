//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Amplitude_iOS
import Mixpanel
import Smartlook
import Flurry_iOS_SDK

typealias Value = MixpanelType

class MPTracker {
    static let shared = MPTracker()

    private var screens = [ Screen ]()
    private var pending = [ String: (start: Date, smartlook: Any) ]()

    private init() {
        // Heap
        Heap.setAppId( "" )
        Heap.startEVPairing()

        // Amplitude
        Amplitude.instance().initializeApiKey( "" )

        // Mixpanel
        Mixpanel.initialize( token: "" )

        // Smartlook
        Smartlook.setup( key: "" )
        Smartlook.startRecording()

        // Flurry
        Flurry.startSession( "", with: FlurrySessionBuilder()
                .withCrashReporting( true ).withIAPReportingEnabled( true ) )
    }

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        self.event( file: file, line: line, function: function, dso: dso,
                    named: "\(productName) #launch", [ "version": productVersion, "build": productBuild ] )
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String) -> Screen {
        let screen = Screen( name: name, tracker: self )
        self.screens.append( screen )

        screen.begin( file: file, line: line, function: function, dso: dso )
        screen.event( file: file, line: line, function: function, dso: dso, event: "open" )

        return screen
    }

    @discardableResult
    func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String) -> Event {
        dbg( file: file, line: line, function: function, dso: dso, "> %@", name )

        Mixpanel.mainInstance().time( event: name )
        let smartlook = Smartlook.startTimedCustomEvent( name: name, props: nil )
        Flurry.logEvent( name, timed: true )

        self.pending[name] = (start: Date(), smartlook: smartlook)

        return Event( pending: name )
    }

    func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String, _ parameters: [String: Value] = [:]) {
        let pending = self.pending.removeValue( forKey: name )

        var eventParameters = parameters
        if let pending = pending {
            eventParameters["duration"] = Date().timeIntervalSince( pending.start )
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
        if let pending = pending {
            Smartlook.trackTimedCustomEvent( eventId: pending.smartlook, props: eventParameters.mapValues { String( describing: $0 ) } )
            Flurry.endTimedEvent( name, withParameters: eventParameters )
        }
        else {
            Smartlook.trackCustomEvent( name: name, props: eventParameters.mapValues { String( describing: $0 ) } )
            Flurry.logEvent( name, withParameters: eventParameters )
        }
    }

    class Screen {
        let name: String
        private let tracker: MPTracker

        init(name: String, tracker: MPTracker) {
            self.name = name
            self.tracker = tracker
        }

        @discardableResult
        fileprivate func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle)
                        -> Event {
            self.tracker.begin( file: file, line: line, function: function, dso: dso, named: self.name )
        }

        @discardableResult
        func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String) -> Event {
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

    class Event {
        let pending: String
        private var ended = false

        init(pending: String) {
            self.pending = pending
        }

        func end(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 _ parameters: [String: Value] = [:]) {
            guard !self.ended
            else { return }

            MPTracker.shared.event( file: file, line: line, function: function, dso: dso, named: self.pending, parameters )
            self.ended = true
        }
    }
}
