import AVFoundation
import SwiftUI

/// 읽어주기 설정 – "나" 탭에서 바꿉니다
enum SpeechSettings {
    static let voiceKey = "ttsVoice"   // 비어 있으면 가장 좋은 음성을 자동 선택
    static let rateKey = "ttsRate"

    enum Rate: String, CaseIterable, Identifiable {
        case slow = "천천히"
        case normal = "보통"
        case fast = "빠르게"
        var id: String { rawValue }

        var value: Float {
            switch self {
            case .slow: AVSpeechUtteranceDefaultSpeechRate * 0.8
            case .normal: AVSpeechUtteranceDefaultSpeechRate * 0.95
            case .fast: AVSpeechUtteranceDefaultSpeechRate * 1.1
            }
        }
    }

    /// 아이폰에 설치된 한국어 음성 (좋은 음질 순)
    static var koreanVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ko-KR" }
            .sorted { rank($0) > rank($1) || (rank($0) == rank($1) && $0.name < $1.name) }
    }

    static func rank(_ v: AVSpeechSynthesisVoice) -> Int {
        switch v.quality {
        case .premium: 3
        case .enhanced: 2
        default: 1
        }
    }

    static func qualityLabel(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.quality {
        case .premium: "최고 음질"
        case .enhanced: "고음질"
        default: "기본"
        }
    }

    /// 저장된 음성, 없으면 설치된 것 중 가장 좋은 음성
    static func selectedVoice() -> AVSpeechSynthesisVoice? {
        let id = UserDefaults.standard.string(forKey: voiceKey) ?? ""
        if !id.isEmpty, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return koreanVoices.first ?? AVSpeechSynthesisVoice(language: "ko-KR")
    }

    static func selectedRate() -> Float {
        (Rate(rawValue: UserDefaults.standard.string(forKey: rateKey) ?? "") ?? .normal).value
    }
}

/// 말씀·기도문 읽어주기 (아이폰 내장 음성, 추가 비용 없음)
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    /// 지금 읽고 있는 항목의 id (없으면 nil)
    @Published private(set) var speakingID: String?
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
        // 무음 모드에서도 들리도록
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    func toggle(_ text: String, id: String) {
        if speakingID == id {
            stop()
            return
        }
        speak(text, id: id)
    }

    func speak(_ text: String, id: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = SpeechSettings.selectedVoice()
        utterance.rate = SpeechSettings.selectedRate()
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        speakingID = id
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingID = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingID = nil }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingID = nil }
    }
}

/// "듣기 / 멈춤" 버튼
struct ListenButton: View {
    let text: String
    let id: String
    @ObservedObject private var speaker = Speaker.shared

    var body: some View {
        let speaking = speaker.speakingID == id
        Button {
            speaker.toggle(text, id: id)
        } label: {
            Label(speaking ? "멈춤" : "듣기", systemImage: speaking ? "stop.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .onDisappear { if speaking { speaker.stop() } }
    }
}

/// "나" 탭의 읽어주기 설정 구역
struct SpeechSettingsSection: View {
    @AppStorage(SpeechSettings.voiceKey) private var voiceID = ""
    @AppStorage(SpeechSettings.rateKey) private var rate = SpeechSettings.Rate.normal.rawValue
    @State private var voices: [AVSpeechSynthesisVoice] = []

    private var hasGoodVoice: Bool { voices.contains { $0.quality != .default } }

    var body: some View {
        Section {
            Picker("목소리", selection: $voiceID) {
                Text("자동 (가장 좋은 음성)").tag("")
                ForEach(voices, id: \.identifier) { v in
                    Text("\(v.name) · \(SpeechSettings.qualityLabel(v))").tag(v.identifier)
                }
            }
            Picker("읽는 속도", selection: $rate) {
                ForEach(SpeechSettings.Rate.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Button {
                Speaker.shared.speak("수고하고 무거운 짐 진 자들아 다 내게로 오라. 내가 너희를 쉬게 하리라.", id: "sample")
            } label: {
                Label("미리 듣기", systemImage: "play.circle")
            }
        } header: {
            Text("읽어주기")
        } footer: {
            Text(hasGoodVoice
                 ? "더 자연스러운 목소리는 아이폰 설정 → 손쉬운 사용 → 읽기 및 말하기 → 음성 → 한국어에서 추가로 받을 수 있어요."
                 : "지금은 기본 음성만 있어요. 아이폰 설정 → 손쉬운 사용 → 읽기 및 말하기 → 음성 → 한국어에서 \"향상됨\" 또는 \"고품질\" 음성을 내려받으면 훨씬 자연스러워져요.")
        }
        .onAppear { voices = SpeechSettings.koreanVoices }
    }
}
