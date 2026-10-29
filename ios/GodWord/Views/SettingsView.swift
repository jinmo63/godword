import SwiftUI
import SwiftData

/// 글씨 크기 – 시스템 설정보다 작아지지 않게 "최소 크기"로 적용합니다
enum TextSizeOption: String, CaseIterable, Identifiable {
    case standard = "기본"
    case large = "크게"
    case extraLarge = "아주 크게"

    static let key = "textSize"
    var id: String { rawValue }

    var range: ClosedRange<DynamicTypeSize> {
        switch self {
        case .standard: .xSmall ... .accessibility5
        case .large: .xxLarge ... .accessibility5
        case .extraLarge: .accessibility1 ... .accessibility5
        }
    }
}

/// "설정" 탭 – 이용 현황, 화면, 도움, 개인정보, 앱 정보 (개발 빌드에서만 개발자 설정)
struct SettingsView: View {
    @AppStorage("remainingToday") private var remainingToday = -1
    @AppStorage(TextSizeOption.key) private var textSize = TextSizeOption.standard.rawValue
    @AppStorage(Consent.versionKey) private var consentVersion = ""
    @AppStorage(Consent.dateKey) private var consentDate = 0.0
    @AppStorage(Profile.nameKey) private var profileName = ""
    @AppStorage(Profile.birthdateKey) private var profileBirthdate = 0.0
    @AppStorage(Profile.hasBirthdateKey) private var hasBirthdate = false
    @Environment(\.modelContext) private var context
    @State private var confirmWithdraw = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("이름 (선택)", text: Binding(
                        get: { profileName },
                        set: { profileName = String($0.prefix(Profile.nameLimit)) }
                    ))
                    .textContentType(.givenName)
                    .submitLabel(.done)

                    Toggle("생년월일 사용", isOn: Binding(
                        get: { hasBirthdate },
                        set: { on in
                            // 처음 켤 때만 기본값을 넣고, 숨겼다 다시 켜면 예전 날짜를 그대로 보여 줌
                            if on && !Profile.hasStoredBirthdate {
                                profileBirthdate = Profile.defaultBirthdate.timeIntervalSince1970
                            }
                            hasBirthdate = on
                        }
                    ))
                    if hasBirthdate {
                        DatePicker(
                            "생년월일",
                            selection: Binding(
                                get: { Date(timeIntervalSince1970: profileBirthdate) },
                                set: { profileBirthdate = $0.timeIntervalSince1970 }
                            ),
                            in: ...Date.now,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    } else if Profile.hasStoredBirthdate {
                        HStack {
                            Label("생년월일 숨김", systemImage: "eye.slash")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("완전히 지우기", role: .destructive) {
                                UserDefaults.standard.removeObject(forKey: Profile.birthdateKey)
                                profileBirthdate = 0
                                UserDefaults.standard.removeObject(forKey: Profile.birthdateKey)
                            }
                            .buttonStyle(.borderless)
                            .font(.footnote)
                        }
                    }
                } header: {
                    Text("내 정보")
                } footer: {
                    Text("한 번만 입력하면 처방할 때마다 다시 묻지 않아요. 생년월일을 끄면 화면과 처방에서 숨겨지고, 다시 켜면 예전 날짜가 그대로 돌아와요. 모든 정보는 이 기기에만 저장돼요.")
                }

                Section {
                    LabeledContent("오늘 남은 무료 처방", value: remainingToday >= 0 ? "\(remainingToday)회" : "-")
                } header: {
                    Text("이용 현황")
                } footer: {
                    Text("무료 처방은 매일 자정(한국 시간)에 다시 채워져요.")
                }

                Section {
                    Picker("글씨 크기", selection: $textSize) {
                        ForEach(TextSizeOption.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                } header: {
                    Text("화면")
                } footer: {
                    Text("글씨가 작게 느껴지면 \"크게\"나 \"아주 크게\"를 골라 보세요.")
                }

                SpeechSettingsSection()

                Section("도움이 필요할 때") {
                    Link(destination: URL(string: "tel:109")!) {
                        Label("자살예방상담전화 109 (24시간)", systemImage: "phone")
                    }
                    Link(destination: URL(string: "tel:15770199")!) {
                        Label("정신건강위기상담 1577-0199", systemImage: "phone")
                    }
                }

                Section {
                    LabeledContent(
                        "동의한 날",
                        value: consentDate > 0
                            ? Date(timeIntervalSince1970: consentDate).formatted(date: .long, time: .omitted)
                            : "-"
                    )
                    NavigationLink("동의 내용 보기") {
                        ConsentView(readOnly: true)
                    }
                    Button("동의 철회 및 데이터 삭제", role: .destructive) {
                        confirmWithdraw = true
                    }
                } header: {
                    Text("개인정보")
                } footer: {
                    Text("동의를 철회하면 이 기기의 처방 기록과 내 정보가 모두 지워지고 처음 화면으로 돌아가요.")
                }

                Section("앱 정보") {
                    LabeledContent("버전", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                }

                #if DEBUG
                DeveloperSection()
                #endif
            }
            .navigationTitle("설정")
            .confirmationDialog(
                "동의를 철회할까요?",
                isPresented: $confirmWithdraw,
                titleVisibility: .visible
            ) {
                Button("철회하고 기록 모두 삭제", role: .destructive) { withdraw() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 기기에 저장된 처방 기록이 모두 삭제되며 되돌릴 수 없어요.")
            }
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
        }
    }

    private func withdraw() {
        try? context.delete(model: SavedPrescription.self)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: "remainingToday")
        profileName = ""
        UserDefaults.standard.removeObject(forKey: Profile.birthdateKey)
        hasBirthdate = false
        consentDate = 0
        consentVersion = "" // ContentView가 다시 동의 화면을 보여줌
    }
}

#if DEBUG
/// 개발자 설정 – 개발 빌드(Xcode에서 실행)에서만 보이고, App Store 버전에서는 숨겨집니다
private struct DeveloperSection: View {
    @AppStorage(APIClient.serverURLKey) private var serverURL = APIClient.defaultServerURL
    @State private var status: String?
    @State private var checking = false
    @FocusState private var editingURL: Bool

    var body: some View {
        Section {
            TextField("서버 주소", text: $serverURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($editingURL)
                .submitLabel(.done)
                .onSubmit { Task { await check() } }
            Button {
                editingURL = false
                Task { await check() }
            } label: {
                HStack {
                    Text("연결 확인")
                    Spacer()
                    if checking { ProgressView() }
                }
            }
            if let status {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("기본값으로 되돌리기") { serverURL = APIClient.defaultServerURL }
            LabeledContent("기기 ID", value: String(APIClient.deviceID.prefix(8)))
            NavigationLink("아이폰 AI(온디바이스) 테스트") { OnDeviceAITestView() }
        } header: {
            Text("개발자 설정")
        } footer: {
            Text("기본 주소: \(APIClient.defaultServerURL)\n이 항목은 개발 빌드에서만 보여요.")
        }
    }

    private func check() async {
        serverURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        checking = true
        defer { checking = false }
        do {
            let h = try await APIClient().health()
            status = h.ok
                ? "연결됨 · 모델 \(h.model)\(h.hasApiKey ? "" : " · 서버에 API 키 없음")"
                : "서버 응답 이상"
        } catch {
            status = "연결 실패: \(error.localizedDescription)"
        }
    }
}
#endif

#Preview {
    SettingsView()
}
