import SwiftUI

/// 고음질 한국어 음성 받는 방법 안내
/// - 기본 음성만 있는 사용자가 처음 "듣기"를 누를 때 한 번 자동으로 보여 줌
/// - "나" 탭 → 읽어주기에서 언제든 다시 열 수 있음
struct VoiceGuideView: View {
    static let shownKey = "voiceGuideShown"

    /// "듣기"에서 열었을 때: 안내를 닫고 기본 음성으로 바로 듣기
    var onListenNow: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var hasGoodVoice = SpeechSettings.hasGoodVoice

    private let steps: [(symbol: String, tint: Color, title: String, detail: String)] = [
        ("gearshape.fill", .gray, "설정 앱 열기", "홈 화면의 회색 톱니바퀴 \"설정\"을 눌러요."),
        ("accessibility", .blue, "손쉬운 사용", "설정 목록에서 \"손쉬운 사용\"을 눌러요."),
        ("text.bubble.fill", .blue, "읽기 및 말하기", "\"읽기 및 말하기\" → \"음성\"을 눌러요."),
        ("globe", .teal, "한국어 고르기", "언어 목록에서 \"한국어\"를 눌러요."),
        ("arrow.down.circle.fill", .green, "고음질 음성 받기", "\"향상됨\" 또는 \"고품질\"이 붙은 목소리(예: 유나)를 눌러 내려받아요. 와이파이에서 받으세요."),
        ("checkmark.circle.fill", .accentColor, "앱으로 돌아오기", "말씀의 위로로 돌아오면 새 목소리로 읽어 드려요."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        Text("더 자연스러운 목소리로\n말씀을 들어 보세요")
                            .font(.title2.bold())
                        Text("지금은 아이폰 기본 목소리라 기계음처럼 들릴 수 있어요. 고음질 목소리는 무료이고, 한 번만 받으면 돼요.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if hasGoodVoice {
                        Label("고음질 목소리가 준비됐어요!", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            StepRow(number: index + 1, symbol: step.symbol, tint: step.tint,
                                    title: step.title, detail: step.detail,
                                    isLast: index == steps.count - 1)
                        }
                    }

                    VStack(spacing: 12) {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        } label: {
                            Label("설정 앱 열기", systemImage: "gearshape")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Text("설정 앱이 열리면 왼쪽 위 \"< 설정\"을 눌러 처음 화면으로 간 뒤, 위 순서대로 따라 하세요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let onListenNow {
                            Button {
                                dismiss()
                                onListenNow()
                            } label: {
                                Text(hasGoodVoice ? "새 목소리로 듣기" : "지금은 기본 목소리로 듣기")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }

                    Text("자녀분이나 교회 리더가 대신 설정해 드려도 좋아요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("목소리 안내")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            // 설정 앱에서 돌아오면 새로 받은 목소리가 있는지 다시 확인
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { hasGoodVoice = SpeechSettings.hasGoodVoice }
            }
        }
        .onAppear { UserDefaults.standard.set(true, forKey: Self.shownKey) }
    }
}

private struct StepRow: View {
    let number: Int
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12))
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(number). \(title)")
                    .font(.headline)
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 20)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VoiceGuideView(onListenNow: {})
}
