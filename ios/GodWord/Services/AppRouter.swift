import SwiftUI

/// 하단 탭 선택과 "홈으로" 이동을 관리합니다
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable {
        case today, prescribe, records, me
    }

    @Published var tab: Tab = .today
    /// 바뀌면 모든 탭의 화면 쌓임(NavigationStack)이 처음 화면으로 돌아갑니다
    @Published private(set) var resetID = UUID()

    /// 어느 화면에 있든 "오늘" 탭 첫 화면으로
    func goHome() {
        Speaker.shared.stop()
        resetID = UUID()
        tab = .today
    }
}

/// 상단 오른쪽 "홈" 버튼
struct HomeButton: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        Button {
            router.goHome()
        } label: {
            Image(systemName: "house")
        }
        .accessibilityLabel("홈으로")
    }
}
