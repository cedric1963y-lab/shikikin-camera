import SwiftUI

@main
struct ShikikinApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var purchase = Purchase()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(purchase)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.05, green: 0.45, blue: 0.47)
    static let warm = Color(red: 0.93, green: 0.49, blue: 0.20)
    static let warn = Color(red: 0.86, green: 0.33, blue: 0.24)
}

struct ContentView: View {
    @State private var tab = Showcase.initialTab
    var body: some View {
        TabView(selection: $tab) {
            PropertyListView()
                .tabItem { Label("物件", systemImage: "house.fill") }.tag(0)
            NavigationStack { MeasureHubView(propertyID: nil) }
                .tabItem { Label("計測", systemImage: "gauge.with.dots.needle.33percent") }.tag(1)
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }.tag(2)
        }
    }
}
