/*
 Copyright © 2023 Gunnar Beutner,
 Copyright © 2022 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI
import OpenUWB

class AppState: ObservableObject {
    @Published var distanceInfo = ""
}

@main
class OpenUWBDemoWatchApp: App {
    @ObservedObject var appState = AppState()
    private var uwbManager: OpenUWB.UWBManager!
    private var accessories: [String: UWBAccessory] = [:]
    private var distances: [String: Float?] = [:]

    /*func handleUserDidNotAllow() {
        // Beginning in iOS 15, persistent access state in Settings.
        //updateInfoLabel(with: "Nearby Interactions access required. You can change access for NIAccessory in Settings.")
        
        // Create an alert to request the user go to Settings.
        let accessAlert = UIAlertController(title: "Access Required",
                                            message: """
                                            OpenUWB requires access to Nearby Interactions for this sample app.
                                            Use this string to explain to users which functionality will be enabled if they change
                                            Nearby Interactions access in Settings.
                                            """,
                                            preferredStyle: .alert)
        accessAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        accessAlert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: {_ in
            // Navigate the user to the app's settings.
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))

        // Preset the access alert.
        present(accessAlert, animated: true, completion: nil)
    }*/
    
    required init() {
        uwbManager = UWBManager()
        uwbManager.delegate = self
        uwbManager.run()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}

extension OpenUWBDemoWatchApp: UWBManagerDelegate {
    func didUpdateAccessory(accessory: UWBAccessory) {
        distances[accessory.publicIdentifier] = accessory.nearbyObject?.distance
        appState.distanceInfo = distances.map {
            String(format: "%@: %0.1fm\n", $0.key, $0.value ?? "?")
        }.joined()
    }
    
    func didConnect(accessory: BluetoothAccessory) {
        distances[accessory.publicIdentifier] = nil
    }
    
    func didFailToConnect(accessory: BluetoothAccessory) {
        distances.removeValue(forKey: accessory.publicIdentifier)
    }

    func didDisconnect(accessory: BluetoothAccessory) {
        distances.removeValue(forKey: accessory.publicIdentifier)
    }
}
