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
    @AppStorage(Consent.versionKey) private var consentVersion = ""

    var body: some View {
        if consentVersion != Consent.version {
            // 처음 실행했거나 동의 문구가 바뀌었으면 동의부터 받습니다
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
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
