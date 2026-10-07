import SwiftUI
import Charts
import SafariServices

/// 처방 결과 – 말씀 · 위로 편지 · 기도문 · 5지표 · 공유
struct ResultView: View {
    let prescription: Prescription
    let date: Date

    @Environment(\.displayScale) private var displayScale
    @State private var cardImage: UIImage?
    @State private var isSharing = false
    @State private var shareError: String?
    @State private var kakaoWebURL: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if prescription.crisis {
                    CrisisBanner()
                }

                Text(prescription.summary)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(prescription.verses, id: \.self) { verse in
                    VerseCard(verse: verse)
                }

                SectionCard(title: "위로 편지", symbol: "envelope.open") {
                    Text(prescription.letter)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }

                SectionCard(title: "기도문", symbol: "hands.sparkles") {
                    Text(prescription.prayer)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }

                SectionCard(title: "오늘의 마음 날씨", symbol: "chart.bar") {
                    EnergyChart(energy: prescription.energy)
                }

                if let usage = prescription.usage {
                    Text("오늘 남은 무료 처방: \(usage.remaining)회")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(date.formatted(.dateTime.month().day().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSharing {
                ProgressView()
            } else if let cardImage {
                let image = Image(uiImage: cardImage)
                Menu {
                    Button {
                        Task { await shareToKakao(cardImage) }
                    } label: {
                        Label("카카오톡으로 공유", systemImage: "message.fill")
                    }
                    ShareLink(item: image, preview: SharePreview(prescription.summary, image: image)) {
                        Label("다른 앱으로 공유", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .alert("공유하지 못했어요", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(shareError ?? "")
        }
        .sheet(item: $kakaoWebURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        .task { renderShareImage() }
    }

    /// 카카오톡 등에 공유할 카드 이미지를 만듭니다
    private func renderShareImage() {
        let renderer = ImageRenderer(content: ShareCardView(prescription: prescription))
        renderer.scale = displayScale
        cardImage = renderer.uiImage
    }

    private func shareToKakao(_ image: UIImage) async {
        isSharing = true
        defer { isSharing = false }
        do {
            if let webURL = try await KakaoShare.share(prescription, cardImage: image) {
                // 카카오톡이 없으면 앱 안에서 웹 공유 화면을 띄움 ("완료"로 바로 돌아옴)
                kakaoWebURL = IdentifiableURL(url: webURL)
            }
        } catch {
            shareError = KakaoShare.describe(error)
            print("[KakaoShare] \(error)")
        }
    }
}

// MARK: - 구성 요소

private struct VerseCard: View {
    let verse: Verse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verse.reference)
                .font(.subheadline.bold())
                .foregroundStyle(.tint)
            Text(verse.text)
                .font(.body.weight(.medium))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            Text(verse.why)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct EnergyChart: View {
    let energy: Energy

    var body: some View {
        Chart(energy.items, id: \.name) { item in
            BarMark(
                x: .value("값", item.value),
                y: .value("지표", item.name)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(4)
            .annotation(position: .trailing) {
                Text("\(item.value)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(domain: 0...100)
        .chartXAxis(.hidden)
        .frame(height: 180)
    }
}

/// 자해·자살 위험 신호가 있을 때 맨 위에 보여주는 상담 안내
private struct CrisisBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("혼자 견디지 않아도 괜찮아요", systemImage: "heart.circle.fill")
                .font(.headline)
            Text("지금 많이 힘드시다면 전문 상담사와 이야기해 보세요. 24시간 연결됩니다.")
                .font(.subheadline)
            HStack {
                Link(destination: URL(string: "tel:109")!) {
                    Label("109 자살예방상담", systemImage: "phone.fill")
                }
                .buttonStyle(.borderedProminent)
                Link(destination: URL(string: "tel:119")!) {
                    Label("119", systemImage: "phone.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        ResultView(prescription: .sample, date: .now)
    }
}

extension Prescription {
    static let sample = Prescription(
        summary: "멈춘 게 아니라 아직 가는 중이에요",
        verses: [
            Verse(book: "시편", chapter: 27, verseStart: 14, verseEnd: 14,
                  text: "너는 여호와를 기다릴지어다 강하고 담대하며 여호와를 기다릴지어다",
                  why: "기다림의 시간이 헛되지 않다는 약속을 전하고 싶었어요."),
        ],
        letter: "민지 님, 2년이라는 시간 동안 얼마나 애써 왔을지요.\n\n오늘만큼은 스스로에게 수고했다고 말해 주세요.",
        prayer: "하나님, 지친 저를 안아 주세요. 저만의 때를 믿는 마음을 주세요. 아멘.",
        energy: Energy(faith: 45, hope: 25, love: 50, joy: 15, peace: 20),
        crisis: false,
        usage: Usage(used: 1, limit: 3, remaining: 2)
    )
}

// MARK: - 앱 안 웹 화면 (카카오 웹 공유용)

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
