import AVFoundation
import SwiftUI

/// 읽어주기 설정 – "설정" 탭에서 바꿉니다
enum SpeechSettings {
    static let voiceKey = "ttsVoice"   // 비어 있으면 가장 좋은 음성을 자동 선택
    /// 읽는 속도 (기본 속도에 곱하는 배율, 0.6 ~ 1.4)
    static let rateScaleKey = "ttsRateScale"
    static let defaultRateScale = 0.95
    static let rateRange = 0.6...1.4

    static func rateLabel(_ scale: Double) -> String {
        switch scale {
        case ..<0.75: "아주 천천히"
        case ..<0.9: "천천히"
        case ..<1.05: "보통"
        case ..<1.2: "빠르게"
        default: "아주 빠르게"
        }
    }

    /// 아이폰에 설치된 한국어 음성 (좋은 음질 순)
    static var koreanVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ko-KR" }
            .sorted { rank($0) > rank($1) || (rank($0) == rank($1) && $0.name < $1.name) }
    }

    /// 기본보다 좋은(향상됨·고품질) 한국어 음성이 설치되어 있는지
    static var hasGoodVoice: Bool {
        koreanVoices.contains { $0.quality != .default }
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
        let saved = UserDefaults.standard.object(forKey: rateScaleKey) as? Double ?? defaultRateScale
        let scale = min(max(saved, rateRange.lowerBound), rateRange.upperBound)
        return AVSpeechUtteranceDefaultSpeechRate * Float(scale)
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
    @AppStorage(VoiceGuideView.shownKey) private var guideShown = false
    @State private var showGuide = false

    var body: some View {
        let speaking = speaker.speakingID == id
        Button {
            // 기본 음성만 있으면 처음 한 번은 고음질 음성 받는 방법을 먼저 안내
            if !speaking && !guideShown && !SpeechSettings.hasGoodVoice {
                showGuide = true
            } else {
                speaker.toggle(text, id: id)
            }
        } label: {
            Label(speaking ? "멈춤" : "듣기", systemImage: speaking ? "stop.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .onDisappear { if speaking { speaker.stop() } }
        .sheet(isPresented: $showGuide) {
            VoiceGuideView(onListenNow: { speaker.speak(text, id: id) })
        }
    }
}

/// "설정" 탭의 읽어주기 설정 구역
struct SpeechSettingsSection: View {
    @AppStorage(SpeechSettings.voiceKey) private var voiceID = ""
    @AppStorage(SpeechSettings.rateScaleKey) private var rateScale = SpeechSettings.defaultRateScale
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var showGuide = false

    private var hasGoodVoice: Bool { voices.contains { $0.quality != .default } }

    var body: some View {
        Section {
            Picker("목소리", selection: $voiceID) {
                Text("자동 (가장 좋은 음성)").tag("")
                ForEach(voices, id: \.identifier) { v in
                    Text("\(v.name) · \(SpeechSettings.qualityLabel(v))").tag(v.identifier)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("읽는 속도")
                    Spacer()
                    Text(SpeechSettings.rateLabel(rateScale))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Image(systemName: "tortoise")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Slider(value: $rateScale, in: SpeechSettings.rateRange, step: 0.05) { editing in
                        // 손을 떼면 바뀐 속도로 짧게 들려줌
                        if !editing { playSample() }
                    }
                    .accessibilityLabel("읽는 속도")
                    .accessibilityValue(SpeechSettings.rateLabel(rateScale))
                    Image(systemName: "hare")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                Button("보통 속도로 되돌리기") {
                    rateScale = SpeechSettings.defaultRateScale
                    playSample()
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
            Button {
                playSample()
            } label: {
                Label("미리 듣기", systemImage: "play.circle")
            }
            Button {
                showGuide = true
            } label: {
                Label("더 자연스러운 목소리 받는 방법", systemImage: "questionmark.circle")
            }
        } header: {
            Text("읽어주기")
        } footer: {
            Text(hasGoodVoice
                 ? "고음질 목소리를 쓰고 있어요. 다른 목소리도 같은 방법으로 더 받을 수 있어요."
                 : "지금은 기본 목소리만 있어요. 위 \"더 자연스러운 목소리 받는 방법\"을 눌러 고음질 목소리를 받아 보세요.")
        }
        .onAppear { voices = SpeechSettings.koreanVoices }
        .sheet(isPresented: $showGuide, onDismiss: { voices = SpeechSettings.koreanVoices }) {
            VoiceGuideView()
        }
    }

    private func playSample() {
        Speaker.shared.speak("수고하고 무거운 짐 진 자들아 다 내게로 오라. 내가 너희를 쉬게 하리라.", id: "sample")
    }
}
