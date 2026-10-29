import Foundation
import FoundationModels

@Generable struct GVerse {
    @Guide(description: "성경 책 이름, 후보 목록 표기 그대로") var book: String
    var chapter: Int
    var verse_start: Int
    @Guide(description: "한 절이면 verse_start와 같게") var verse_end: Int
    @Guide(description: "개역개정에 가까운 구절 본문") var text: String
    @Guide(description: "이 구절을 고른 이유, 한두 문장") var why: String
}
@Generable struct GEnergy {
    @Guide(.range(0...100)) var faith: Int
    @Guide(.range(0...100)) var hope: Int
    @Guide(.range(0...100)) var love: Int
    @Guide(.range(0...100)) var joy: Int
    @Guide(.range(0...100)) var peace: Int
}
@Generable struct GResult {
    @Guide(description: "결과 카드 제목, 25자 이내") var summary: String
    @Guide(description: "1~3개", .count(1...3)) var verses: [GVerse]
    @Guide(description: "위로 편지 400~700자, 3~4문단") var letter: String
    @Guide(description: "1인칭 기도문 200~400자") var prayer: String
    var energy: GEnergy
    @Guide(description: "자해·자살·학대·폭력 위험 신호가 있으면 true") var crisis: Bool
}

struct Input: Decodable { let system: String; let cases: [Case] }
struct Case: Decodable { let id, mode, input, user: String }

@main struct Run {
    static func main() async throws {
        let inp = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        var out: [[String: Any]] = []
        for c in inp.cases {
            let s = LanguageModelSession(instructions: inp.system)
            let t = Date()
            var row: [String: Any] = ["id": c.id, "mode": c.mode, "input": c.input]
            do {
                let r = try await s.respond(to: c.user, generating: GResult.self)
                let g = r.content
                row["seconds"] = Date().timeIntervalSince(t)
                row["result"] = [
                    "summary": g.summary,
                    "verses": g.verses.map { ["book": $0.book, "chapter": $0.chapter, "verse_start": $0.verse_start, "verse_end": $0.verse_end, "text": $0.text, "why": $0.why] },
                    "letter": g.letter, "prayer": g.prayer,
                    "energy": ["faith": g.energy.faith, "hope": g.energy.hope, "love": g.energy.love, "joy": g.energy.joy, "peace": g.energy.peace],
                    "crisis": g.crisis,
                ] as [String: Any]
            } catch {
                row["seconds"] = Date().timeIntervalSince(t)
                row["error"] = "\(error)"
            }
            print(c.id, String(format: "%.1fs", row["seconds"] as! Double), row["error"] == nil ? "ok" : "ERROR \(row["error"]!)")
            out.append(row)
        }
        let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .withoutEscapingSlashes])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
}
