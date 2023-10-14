/*
 Copyright © 2023 Gunnar Beutner,
 Copyright © 2022 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import UIKit
import os.log
import OpenUWB
import AVFoundation

class AccessoryDemoViewController: UIViewController {
    private var uwbManager: UWBManager!
    private var accessories: [String: UWBAccessory] = [:]
    private var distances: [String: Float?] = [:]

    let logger = os.Logger(subsystem: "name.beutner.OpenUWBDemo", category: "AccessoryDemoViewController")

    @IBOutlet weak var connectionStateLabel: UILabel!
    @IBOutlet weak var uwbStateLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateInfoLabel(with: "Scanning for accessories")

        var uwbManagerOptions = UWBManagerOptions()
        if #available(iOS 16.0, *) {
            uwbManagerOptions.useCameraAssistance = true
        }
        uwbManager = UWBManager(delegate: self, options: uwbManagerOptions)
        uwbManager.start()
    }
}

extension AccessoryDemoViewController : UWBManagerDelegate {
    func didUpdateAccessory(accessory: UWBAccessory) {
        distances[accessory.publicIdentifier] = accessory.distance
        distanceLabel.text = distances.map {
            String(format: "%@: %@\n", $0.key, $0.value != nil ? String(format: "%0.1fm", $0.value!) : "?")
        }.joined()
        distanceLabel.sizeToFit()
    }
    
    func didDiscover(accessory: BluetoothAccessory, rssi: NSNumber) {
        distances.updateValue(nil, forKey: accessory.publicIdentifier)
        // We're relying on auto-connect here, however we would have
        // to call uwbManager.connect() if it's disabled.
    }

    func didConnect(accessory: BluetoothAccessory) {
        distances.updateValue(nil, forKey: accessory.publicIdentifier)
    }
    
    func didFailToConnect(accessory: BluetoothAccessory) {
        distances.removeValue(forKey: accessory.publicIdentifier)
    }

    func didDisconnect(accessory: BluetoothAccessory) {
        distances.removeValue(forKey: accessory.publicIdentifier)
    }

    func didUpdateBluetoothState(state: Bool) {
        self.connectionStateLabel.text = state ? "Connected" : "Not Connected"
    }
    
    func didUpdateUWBState(state: Bool) {
        self.uwbStateLabel.text = state ? "ON" : "OFF"
    }
    
    func log(_ message: String) {
        updateInfoLabel(with: message)
    }
    
    func didRequirePermissions() {
        // Beginning in iOS 15, persistent access state in Settings.
        updateInfoLabel(with: "Nearby Interactions access required. You can change access for NIAccessory in Settings.")
        
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
    }
}

// MARK: - Helpers.

extension AccessoryDemoViewController {
    func updateInfoLabel(with text: String) {
        self.infoLabel.text = text
        self.distanceLabel.sizeToFit()
        logger.info("\(text)")
    }

}
