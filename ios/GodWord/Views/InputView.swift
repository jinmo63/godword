import SwiftUI
import SwiftData

/// 모드별 입력 화면 → 서버 호출 → 결과 화면
struct InputView: View {
    let mode: Mode

    @Environment(\.modelContext) private var context
    @Query(sort: \SavedPrescription.createdAt, order: .reverse) private var history: [SavedPrescription]

    @State private var name = ""
    @State private var text = ""
    @State private var category: String?
    @State private var birthdate = Calendar.current.date(from: DateComponents(year: 1995, month: 1, day: 1)) ?? .now

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var result: SavedPrescription?

    static let categories = ["감사", "용서", "불안", "외로움", "재정 걱정", "건강", "관계", "진로", "가족", "새로운 시작"]
    private let maxLength = 500

    var body: some View {
        Form {
            Section {
                TextField("이름 (선택)", text: $name)
                    .textContentType(.givenName)
            } footer: {
                Text("이름을 적으면 편지와 기도문에 이름을 넣어 드려요.")
            }

            inputSection

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    Text("말씀 처방 받기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.bold)
            }
        }
        .disabled(isLoading)
        .overlay {
            if isLoading { LoadingView() }
        }
        .alert("알림", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationDestination(item: $result) { saved in
            if let p = saved.prescription {
                ResultView(prescription: p, date: saved.createdAt)
            }
        }
    }

    // MARK: - 모드별 입력

    @ViewBuilder
    private var inputSection: some View {
        switch mode {
        case .worry, .prayer:
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(mode == .worry ? "요즘 마음을 무겁게 하는 일을 편하게 적어 주세요." : "예: 아버지 수술이 잘 끝나게 해주세요")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            } header: {
                Text(mode == .worry ? "고민" : "기도 제목")
            } footer: {
                Text("\(text.count) / \(maxLength)자")
                    .foregroundStyle(text.count > maxLength ? .red : .secondary)
            }

        case .category:
            Section("오늘 마음이 가는 주제") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 10) {
                    ForEach(Self.categories, id: \.self) { item in
                        Button(item) { category = item }
                            .buttonStyle(.bordered)
                            .tint(category == item ? .accentColor : .secondary)
                            .fontWeight(category == item ? .bold : .regular)
                    }
                }
                .padding(.vertical, 6)
            }

        case .birthdate:
            Section {
                DatePicker("생년월일", selection: $birthdate, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
            } header: {
                Text("생년월일")
            } footer: {
                Text("생년월일로 운세를 보지 않아요. 당신을 위한 오늘의 말씀을 고르는 데만 사용해요.")
            }
        }
    }

    // MARK: - 전송

    private var inputValue: String {
        switch mode {
        case .worry, .prayer:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .category:
            return category ?? ""
        case .birthdate:
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: birthdate)
        }
    }

    private var canSubmit: Bool {
        !isLoading && !inputValue.isEmpty && inputValue.count <= maxLength
    }

    /// 최근 받은 구절 – 서버가 같은 구절을 다시 고르지 않게 합니다
    private var recentVerses: [String] {
        var seen = Set<String>()
        return history.prefix(5)
            .flatMap { $0.prescription?.verses.map(\.key) ?? [] }
            .filter { seen.insert($0).inserted }
            .prefix(10)
            .map { $0 }
    }

    private func submit() async {
        isLoading = true
        defer { isLoading = false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        do {
            let prescription = try await APIClient().prescribe(
                mode: mode,
                name: trimmedName.isEmpty ? nil : trimmedName,
                input: inputValue,
                recent: recentVerses
            )
            let saved = SavedPrescription(mode: mode, input: inputValue, prescription: prescription)
            context.insert(saved)
            if let usage = prescription.usage {
                UserDefaults.standard.set(usage.remaining, forKey: "remainingToday")
            }
            result = saved
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { InputView(mode: .worry) }
        .modelContainer(for: SavedPrescription.self, inMemory: true)
}
