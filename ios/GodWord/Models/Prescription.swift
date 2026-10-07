import Foundation
import SwiftData

// MARK: - 처방 모드

enum Mode: String, Codable, CaseIterable, Identifiable {
    case worry = "고민"
    case category = "카테고리"
    case birthdate = "생년월일"
    case prayer = "기도제목"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worry: "고민 상담"
        case .category: "오늘의 주제"
        case .birthdate: "생년월일 처방"
        case .prayer: "기도 제목"
        }
    }

    var subtitle: String {
        switch self {
        case .worry: "마음속 이야기를 들려주세요"
        case .category: "오늘 마음이 가는 주제를 골라요"
        case .birthdate: "나를 위한 오늘의 말씀"
        case .prayer: "기도 제목으로 기도문을 받아요"
        }
    }

    var symbol: String {
        switch self {
        case .worry: "bubble.left.and.text.bubble.right"
        case .category: "square.grid.2x2"
        case .birthdate: "calendar"
        case .prayer: "hands.sparkles"
        }
    }
}

// MARK: - 서버 응답 (server/lib/prompt.ts의 RESULT_SCHEMA와 1:1)

struct Verse: Codable, Hashable {
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int
    let text: String
    let why: String

    enum CodingKeys: String, CodingKey {
        case book, chapter, text, why
        case verseStart = "verse_start"
        case verseEnd = "verse_end"
    }

    /// "시편 23:1-2"
    var reference: String {
        verseEnd > verseStart
            ? "\(book) \(chapter):\(verseStart)-\(verseEnd)"
            : "\(book) \(chapter):\(verseStart)"
    }

    /// 서버의 "최근 받은 구절" 비교용 – "시편 23:1"
    var key: String { "\(book) \(chapter):\(verseStart)" }
}

struct Energy: Codable, Hashable {
    let faith: Int
    let hope: Int
    let love: Int
    let joy: Int
    let peace: Int

    var items: [(name: String, value: Int)] {
        [("믿음", faith), ("소망", hope), ("사랑", love), ("기쁨", joy), ("평안", peace)]
    }
}

struct Usage: Codable, Hashable {
    let used: Int
    let limit: Int
    let remaining: Int
}

struct Prescription: Codable, Hashable {
    let summary: String
    let verses: [Verse]
    let letter: String
    let prayer: String
    let energy: Energy
    let crisis: Bool
    let usage: Usage?
}

// MARK: - 히스토리 저장 (SwiftData)

@Model
final class SavedPrescription {
    var createdAt: Date
    var modeRaw: String
    var input: String
    /// 서버 응답 JSON을 그대로 저장합니다 (스키마가 바뀌어도 저장소는 그대로)
    var payload: Data

    init(mode: Mode, input: String, prescription: Prescription) {
        self.createdAt = .now
        self.modeRaw = mode.rawValue
        self.input = input
        self.payload = (try? JSONEncoder().encode(prescription)) ?? Data()
    }

    var mode: Mode { Mode(rawValue: modeRaw) ?? .worry }
    var prescription: Prescription? { try? JSONDecoder().decode(Prescription.self, from: payload) }
}
