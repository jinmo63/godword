import SwiftUI
import SwiftData

/// "오늘" 탭 – 매일 여는 첫 화면: 최근 받은 말씀, 남은 횟수, 처방 바로가기
struct TodayView: View {
    @Query(sort: \SavedPrescription.createdAt, order: .reverse) private var history: [SavedPrescription]
    @AppStorage("remainingToday") private var remainingToday = -1

    /// 가장 최근에 받은 처방의 첫 구절
    private var latest: (item: SavedPrescription, verse: Verse)? {
        for item in history {
            if let verse = item.prescription?.verses.first { return (item, verse) }
        }
        return nil
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "좋은 아침이에요"
        case 11..<17: "평안한 오후 보내세요"
        case 17..<22: "오늘 하루 수고 많으셨어요"
        default: "편안한 밤 되세요"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date.now.formatted(.dateTime.month().day().weekday(.wide)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(greeting)
                            .font(.title2.bold())
                    }

                    if let latest {
                        LatestVerseCard(item: latest.item, verse: latest.verse)
                    } else {
                        EmptyCard()
                    }

                    if remainingToday >= 0 {
                        Label("오늘 남은 무료 처방 \(remainingToday)회", systemImage: "ticket")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("말씀 처방 바로가기")
                        .font(.headline)
                        .padding(.top, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Mode.allCases) { mode in
                            NavigationLink(value: mode) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: mode.symbol)
                                        .font(.title3)
                                        .foregroundStyle(.tint)
                                        .frame(height: 28)
                                    Text(mode.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("오늘")
            .navigationDestination(for: Mode.self) { mode in
                InputView(mode: mode)
            }
            .navigationDestination(for: SavedPrescription.self) { item in
                if let p = item.prescription {
                    ResultView(prescription: p, date: item.createdAt)
                }
            }
        }
    }
}

private struct LatestVerseCard: View {
    let item: SavedPrescription
    let verse: Verse

    private var shareText: String {
        "\(verse.text)\n— \(verse.reference)\n\n「말씀의 위로」에서 받은 말씀이에요."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("최근 받은 말씀")
                .font(.caption.bold())
                .foregroundStyle(.tint)

            Text(verse.text)
                .font(.title3.weight(.medium))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Text(verse.reference)
                .font(.subheadline.bold())
                .foregroundStyle(.tint)

            HStack {
                ListenButton(text: "\(verse.text). \(verse.reference)", id: "today-\(verse.key)")
                ShareLink(item: shareText) {
                    Label("가족에게 보내기", systemImage: "paperplane")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
            }

            NavigationLink(value: item) {
                HStack {
                    Text("처방 전체 보기")
                    Image(systemName: "chevron.right")
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct EmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "book.pages")
                .font(.title)
                .foregroundStyle(.tint)
            Text("아직 받은 말씀이 없어요")
                .font(.headline)
            Text("아래에서 처방 방식을 골라 첫 말씀을 받아 보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    TodayView()
        .modelContainer(for: SavedPrescription.self, inMemory: true)
}
