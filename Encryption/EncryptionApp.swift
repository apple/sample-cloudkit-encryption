//
//  EncryptionApp.swift
//  (cloudkit-samples) Encryption
//

import SwiftUI

@main
struct EncryptionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(ViewModel())
        }
    }
}
