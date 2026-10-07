import SwiftUI

/// AI 응답을 기다리는 10~20초 동안 보여주는 화면
struct LoadingView: View {
    private let messages = [
        "당신의 이야기를 읽고 있어요",
        "마음에 닿을 말씀을 고르고 있어요",
        "위로의 편지를 쓰고 있어요",
        "함께 드릴 기도문을 준비하고 있어요",
        "거의 다 되었어요",
    ]
    @State private var index = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.94).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "book.pages")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)

                Text(messages[index])
                    .font(.headline)
                    .id(index) // 문구가 바뀔 때 겹치지 않고 새로 나타나게
                    .transition(.opacity)
                    .animation(.easeInOut, value: index)
                    .frame(minHeight: 24)

                ProgressView()

                Text("\"너희 염려를 다 주께 맡기라\" 베드로전서 5:7")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .task {
            while !Task.isCancelled && index < messages.count - 1 {
                try? await Task.sleep(for: .seconds(3.5))
                index += 1
            }
        }
    }
}

#Preview {
    LoadingView()
}
