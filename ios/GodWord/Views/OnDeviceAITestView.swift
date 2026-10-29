#if DEBUG
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 개발용: 아이폰 안의 AI(Apple Foundation Models) 품질 테스트
/// - 기기가 지원하는지 확인하고, 같은 고민으로 위로 편지·기도문을 만들어 봅니다.
struct OnDeviceAITestView: View {
    @State private var status = "확인 전"
    @State private var output = ""
    @State private var seconds: Double?
    @State private var running = false
    @State private var worry = "취업 준비가 2년째 길어지면서 많이 지치고 불안해요. 친구들은 다 자리를 잡았는데 저만 멈춰 있는 것 같아요."

    var body: some View {
        Form {
            Section("지원 여부") {
                Text(status)
                Button("다시 확인") { checkAvailability() }
            }
            Section("고민") {
                TextEditor(text: $worry).frame(minHeight: 100)
                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        Text("아이폰 AI로 처방 만들기")
                        Spacer()
                        if running { ProgressView() }
                    }
                }
                .disabled(running)
            }
            if !output.isEmpty {
                Section(seconds.map { String(format: "결과 (%.1f초)", $0) } ?? "결과") {
                    Text(output).textSelection(.enabled)
                }
            }
        }
        .navigationTitle("아이폰 AI 테스트")
        .onAppear { checkAvailability() }
    }

    private func checkAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                status = "✅ 사용 가능"
            case .unavailable(let reason):
                status = "❌ 사용 불가: \(describe(reason))"
            }
            print("[OnDeviceAI] availability: \(SystemLanguageModel.default.availability)")
            return
        }
        #endif
        status = "❌ iOS 26 이상에서만 지원"
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible: return "이 기기는 Apple Intelligence를 지원하지 않아요"
        case .appleIntelligenceNotEnabled: return "설정에서 Apple Intelligence가 꺼져 있어요"
        case .modelNotReady: return "AI 모델을 내려받는 중이거나 준비되지 않았어요"
        @unknown default: return "알 수 없는 이유 (\(reason))"
        }
    }
    #endif

    private func run() async {
        running = true
        defer { running = false }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                output = "모델을 쓸 수 없어 테스트하지 못했어요."
                return
            }
            let session = LanguageModelSession(instructions: """
            당신은 "말씀의 위로" 앱의 말씀 처방사입니다. 사용자의 고민을 듣고 따뜻하게 위로합니다.
            정죄하거나 훈계하지 않고, 하나님의 사랑과 동행을 중심에 둡니다.
            운세처럼 들리는 표현은 쓰지 않습니다. 한국어로 씁니다.
            """)
            let prompt = """
            고민: \(worry)

            다음 형식으로 답해 주세요.
            [추천 구절] 아래 후보 중 가장 맞는 것 1개의 장절만: 이사야 40:31, 시편 27:14, 전도서 3:11, 갈라디아서 6:9, 시편 139:14
            [위로 편지] 300~500자, 3문단
            [기도문] 1인칭, 200자 내외
            """
            let start = Date()
            do {
                let response = try await session.respond(to: prompt)
                seconds = Date().timeIntervalSince(start)
                output = response.content
                print("[OnDeviceAI] \(String(format: "%.1f", seconds ?? 0))s\n\(response.content)")
            } catch {
                output = "오류: \(error)"
                print("[OnDeviceAI] error: \(error)")
            }
            return
        }
        #endif
        output = "iOS 26 이상에서만 지원해요."
    }
}
#endif
