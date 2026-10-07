import SwiftUI

/// 첫 실행 화면: 소개 → 동의
struct OnboardingView: View {
    @AppStorage(Consent.versionKey) private var consentVersion = ""
    @AppStorage(Consent.dateKey) private var consentDate = 0.0
    @State private var showConsent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image("Welcome")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)

                VStack(spacing: 10) {
                    Text("말씀의 위로")
                        .font(.largeTitle.bold())
                    Text("마음을 들려주시면\n꼭 맞는 말씀과 기도로 위로해 드려요")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(symbol: "book", title: "상황에 맞는 성경 말씀", text: "고민·주제·기도 제목에 맞춰 골라요")
                    FeatureRow(symbol: "envelope.open", title: "위로 편지와 기도문", text: "소리 내어 읽을 수 있는 나만의 기도")
                    FeatureRow(symbol: "lock", title: "기록은 내 기기에만", text: "처방 기록은 이 아이폰에만 저장돼요")
                }
                .padding(.horizontal, 8)

                Spacer()

                Button {
                    showConsent = true
                } label: {
                    Text("시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
            .navigationDestination(isPresented: $showConsent) {
                ConsentView { agreed in
                    guard agreed else { return }
                    consentDate = Date.now.timeIntervalSince1970
                    consentVersion = Consent.version
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

/// 동의 화면 – 필수 항목에 모두 동의해야 시작할 수 있습니다.
/// `readOnly`이면 설정에서 동의 내용을 다시 볼 때 씁니다.
struct ConsentView: View {
    var readOnly = false
    var onFinish: (Bool) -> Void = { _ in }

    @State private var agreed: Set<String> = []
    @State private var detailItem: Consent.Item?

    private var allAgreed: Bool { agreed.count == Consent.items.count }

    var body: some View {
        List {
            if !readOnly {
                Section {
                    Button {
                        agreed = allAgreed ? [] : Set(Consent.items.map(\.id))
                    } label: {
                        HStack(spacing: 12) {
                            CheckMark(on: allAgreed)
                            Text("전체 동의")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                    }
                } footer: {
                    Text("아래 필수 항목에 모두 동의해야 이용할 수 있어요.")
                }
            }

            Section {
                ForEach(Consent.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        if !readOnly {
                            Button {
                                toggle(item.id)
                            } label: {
                                CheckMark(on: agreed.contains(item.id))
                            }
                            .buttonStyle(.plain)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("[필수] \(item.title)")
                                .font(.subheadline.weight(.semibold))
                            Text(item.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { if !readOnly { toggle(item.id) } }
                        Spacer()
                        Button("보기") { detailItem = item }
                            .font(.footnote)
                            .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Label {
                    Text(Consent.notice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "heart.text.square")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(readOnly ? "동의 내용" : "이용 동의")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !readOnly {
                Button {
                    onFinish(true)
                } label: {
                    Text("동의하고 시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!allAgreed)
                .padding()
                .background(.bar)
            }
        }
        .sheet(item: $detailItem) { item in
            NavigationStack {
                ScrollView {
                    Text(item.detail)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("닫기") { detailItem = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func toggle(_ id: String) {
        if agreed.contains(id) { agreed.remove(id) } else { agreed.insert(id) }
    }
}

private struct CheckMark: View {
    let on: Bool
    var body: some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(on ? Color.accentColor : Color.secondary)
            .contentTransition(.symbolEffect(.replace))
    }
}

#Preview("소개") {
    OnboardingView()
}

#Preview("동의") {
    NavigationStack { ConsentView() }
}
