import SwiftUI

/// 설정 – 서버 주소(개발용), 연결 확인, 상담 안내
struct SettingsView: View {
    @AppStorage(APIClient.serverURLKey) private var serverURL = APIClient.defaultServerURL
    @AppStorage("remainingToday") private var remainingToday = -1
    @State private var status: String?
    @State private var checking = false
    @FocusState private var editingURL: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("오늘 남은 무료 처방", value: remainingToday >= 0 ? "\(remainingToday)회" : "-")
                } footer: {
                    Text("무료 처방은 매일 자정(한국 시간)에 다시 채워져요.")
                }

                Section {
                    TextField("서버 주소", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($editingURL)
                        .submitLabel(.done)
                        .onSubmit { Task { await check() } }
                    Button {
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
                } header: {
                    Text("개발용 서버")
                } footer: {
                    Text("기본 주소: \(APIClient.defaultServerURL)\n주소가 바뀌었으면 \"기본값으로 되돌리기\"를 누르세요.")
                }

                Section("도움이 필요할 때") {
                    Link(destination: URL(string: "tel:109")!) {
                        Label("자살예방상담전화 109 (24시간)", systemImage: "phone")
                    }
                    Link(destination: URL(string: "tel:15770199")!) {
                        Label("정신건강위기상담 1577-0199", systemImage: "phone")
                    }
                }

                Section("정보") {
                    LabeledContent("버전", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                    LabeledContent("기기 ID", value: String(APIClient.deviceID.prefix(8)))
                }
            }
            .navigationTitle("설정")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") {
                        editingURL = false
                        Task { await check() }
                    }
                    .fontWeight(.bold)
                }
            }
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

#Preview {
    SettingsView()
}
