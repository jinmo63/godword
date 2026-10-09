import AVFoundation
import SwiftUI

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
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9 // 조금 천천히
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
