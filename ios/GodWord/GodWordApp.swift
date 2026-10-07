import SwiftUI
import SwiftData

@main
struct GodWordApp: App {
    init() {
        KakaoShare.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SavedPrescription.self)
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("말씀 처방", systemImage: "book") }
            HistoryView()
                .tabItem { Label("히스토리", systemImage: "clock") }
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedPrescription.self, inMemory: true)
}
