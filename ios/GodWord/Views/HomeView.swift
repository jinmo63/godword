import SwiftUI

/// 첫 화면 – 4가지 처방 모드 선택
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("오늘, 어떤 말씀이 필요하세요?")
                            .font(.title2.bold())
                        Text("\"수고하고 무거운 짐 진 자들아 다 내게로 오라\"\n마태복음 11:28")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    ForEach(Mode.allCases) { mode in
                        NavigationLink(value: mode) {
                            ModeCard(mode: mode)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("말씀의 위로")
            .navigationDestination(for: Mode.self) { mode in
                InputView(mode: mode)
            }
        }
    }
}

private struct ModeCard: View {
    let mode: Mode

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: mode.symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(.headline)
                Text(mode.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }
}

#Preview {
    HomeView()
}
