import SwiftUI
import SwiftData

/// 지금까지 받은 처방 목록
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedPrescription.createdAt, order: .reverse) private var items: [SavedPrescription]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "아직 받은 말씀이 없어요",
                        systemImage: "book.closed",
                        description: Text("말씀 처방 탭에서 첫 말씀을 받아 보세요.")
                    )
                } else {
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
            }
            .navigationTitle("히스토리")
            .navigationDestination(for: SavedPrescription.self) { item in
                if let p = item.prescription {
                    ResultView(prescription: p, date: item.createdAt)
                }
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

#Preview {
    HistoryView()
        .modelContainer(for: SavedPrescription.self, inMemory: true)
}
