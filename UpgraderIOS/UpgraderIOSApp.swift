
import SwiftUI

@main
struct UpgraderIOSApp: App {
    @StateObject private var store = GameStore()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store) }
    }
}
