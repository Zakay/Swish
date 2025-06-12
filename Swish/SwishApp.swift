//
//  SwishApp.swift
//  Swish
//
//  Created by Zakay Danial on 12/06/2025.
//

import SwiftUI
import AppKit

@main
struct SwishApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
