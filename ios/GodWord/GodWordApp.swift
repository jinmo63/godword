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
    @AppStorage(TextSizeOption.key) private var textSize = TextSizeOption.standard.rawValue

    var body: some View {
        Group {
            if consentVersion != Consent.version {
                // 처음 실행했거나 동의 문구가 바뀌었으면 동의부터 받습니다
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .dynamicTypeSize((TextSizeOption(rawValue: textSize) ?? .standard).range)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("오늘", systemImage: "sun.max") }
            HomeView()
                .tabItem { Label("처방", systemImage: "book") }
            HistoryView()
                .tabItem { Label("내 기록", systemImage: "books.vertical") }
            SettingsView()
                .tabItem { Label("나", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedPrescription.self, inMemory: true)
}
