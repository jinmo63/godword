import SwiftUI
import SwiftData
import Charts

/// "내 기록" 탭 – 처방 기록 · 저장한 말씀 · 마음 날씨 변화
struct HistoryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case prescriptions = "처방 기록"
        case verses = "저장한 말씀"
        case weather = "마음 날씨"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \SavedPrescription.createdAt, order: .reverse) private var items: [SavedPrescription]
    @State private var section: Section = .prescriptions

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("보기", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

                if items.isEmpty {
                    ContentUnavailableView(
                        "아직 받은 말씀이 없어요",
                        systemImage: "book.closed",
                        description: Text("처방 탭에서 첫 말씀을 받아 보세요.")
                    )
                } else {
                    switch section {
                    case .prescriptions: prescriptionList
                    case .verses: verseList
                    case .weather: WeatherTrend(items: items)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("내 기록")
            .navigationDestination(for: SavedPrescription.self) { item in
                if let p = item.prescription {
                    ResultView(prescription: p, date: item.createdAt)
                }
            }
        }
    }

    // MARK: 처방 기록

    private var prescriptionList: some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    HistoryRow(item: item)
                }
            }
            .onDelete { offsets in
                for index in offsets { context.delete(items[index]) }
            }
        }
    }

    // MARK: 저장한 말씀 (같은 구절은 가장 최근 것 하나만)

    private var savedVerses: [(verse: Verse, item: SavedPrescription)] {
        var seen = Set<String>()
        var result: [(Verse, SavedPrescription)] = []
        for item in items {
            for verse in item.prescription?.verses ?? [] where seen.insert(verse.key).inserted {
                result.append((verse, item))
            }
        }
        return result
    }

    private var verseList: some View {
        List(savedVerses, id: \.verse.key) { entry in
            NavigationLink(value: entry.item) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.verse.reference)
                        .font(.subheadline.bold())
                        .foregroundStyle(.tint)
                    Text(entry.verse.text)
                        .font(.body)
                        .lineLimit(3)
                    Text(entry.item.createdAt.formatted(.dateTime.month().day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct HistoryRow: View {
    let item: SavedPrescription

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.prescription?.summary ?? item.input)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(item.mode.title)
                Text("·")
                Text(item.createdAt.formatted(.dateTime.month().day().hour().minute()))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let ref = item.prescription?.verses.first?.reference {
                Text(ref)
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 최근 처방들의 5지표 변화
private struct WeatherTrend: View {
    let items: [SavedPrescription]

    private struct Point: Identifiable {
        let id = UUID()
        let order: Int
        let date: Date
        let name: String
        let value: Int
    }

    /// 오래된 것부터 최근 14개
    private var recent: [SavedPrescription] {
        Array(items.prefix(14).reversed())
    }

    private var points: [Point] {
        recent.enumerated().flatMap { index, item in
            (item.prescription?.energy.items ?? []).map {
                Point(order: index + 1, date: item.createdAt, name: $0.name, value: $0.value)
            }
        }
    }

    private var averages: [(name: String, value: Int)] {
        let energies = recent.compactMap { $0.prescription?.energy }
        guard !energies.isEmpty else { return [] }
        let names = ["믿음", "소망", "사랑", "기쁨", "평안"]
        return names.enumerated().map { i, name in
            let sum = energies.reduce(0) { $0 + $1.items[i].value }
            return (name, sum / energies.count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("최근 \(recent.count)번의 마음 날씨")
                        .font(.headline)
                    if recent.count < 2 {
                        Text("처방을 2번 이상 받으면 변화가 그래프로 보여요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(points) { p in
                            LineMark(x: .value("순서", p.order), y: .value("값", p.value))
                                .foregroundStyle(by: .value("지표", p.name))
                                .symbol(by: .value("지표", p.name))
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis(.hidden)
                        .frame(height: 220)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 12) {
                    Text("평균")
                        .font(.headline)
                    HStack {
                        ForEach(averages, id: \.name) { a in
                            VStack(spacing: 4) {
                                Text("\(a.value)")
                                    .font(.title3.bold())
                                    .foregroundStyle(.tint)
                                Text(a.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                Text("마음 날씨는 처방 때 입력한 내용에서 AI가 읽어낸 값이에요. 평가가 아니라 그날의 마음을 돌아보는 참고용이에요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SavedPrescription.self, inMemory: true)
}
