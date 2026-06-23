//
//  BetterswitchApp.swift
//  Betterswitch
//
//  Created by Luka Managadze on 24/06/2026.
//

import SwiftUI

@main
struct BetterswitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
