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
    @StateObject private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.tab) {
            TodayView()
                .id(router.resetID)
                .tabItem { Label("오늘", systemImage: "sun.max") }
                .tag(AppRouter.Tab.today)
            HomeView()
                .id(router.resetID)
                .tabItem { Label("처방", systemImage: "book") }
                .tag(AppRouter.Tab.prescribe)
            HistoryView()
                .id(router.resetID)
                .tabItem { Label("내 기록", systemImage: "books.vertical") }
                .tag(AppRouter.Tab.records)
            SettingsView()
                .tabItem { Label("나", systemImage: "person.crop.circle") }
                .tag(AppRouter.Tab.me)
        }
        .environmentObject(router)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedPrescription.self, inMemory: true)
}
