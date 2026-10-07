import UIKit
import KakaoSDKCommon
import KakaoSDKShare
import KakaoSDKTemplate

/// 카카오톡 공유
///
/// 흐름: 결과 카드 이미지를 카카오 서버에 올림 → 피드 메시지 만들기 →
///      카카오톡이 있으면 카카오톡으로, 없으면 웹 공유 페이지(Safari)로 보냄
enum KakaoShare {
    /// Config/Kakao.xcconfig의 KAKAO_NATIVE_APP_KEY (Info.plist를 거쳐 들어옴)
    static var appKey: String? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String)?
            .trimmingCharacters(in: .whitespaces)
        return (key?.isEmpty ?? true) ? nil : key
    }

    static var isConfigured: Bool { appKey != nil }

    /// 메시지의 "자세히 보기" 링크로 쓸 웹 주소.
    /// 카카오 개발자 콘솔 > 플랫폼 > Web > 사이트 도메인에 등록한 도메인이어야 합니다.
    /// 아직 웹사이트가 없으면 nil로 두세요 (앱 실행 버튼만 들어갑니다).
    static let webURL: URL? = nil

    /// 앱 시작 시 한 번 호출
    static func setup() {
        guard let appKey else { return }
        KakaoSDK.initSDK(appKey: appKey)
    }

    enum ShareError: LocalizedError {
        case notConfigured
        case cannotOpen

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                "카카오톡 공유가 아직 설정되지 않았어요.\n(개발자: Config/Kakao.xcconfig에 네이티브 앱 키를 넣어 주세요)"
            case .cannotOpen:
                "카카오톡 공유 화면을 열지 못했어요."
            }
        }
    }

    /// 카카오톡이 설치되어 있으면 카카오톡을 열고 nil을 돌려줍니다.
    /// 설치되어 있지 않으면 웹 공유 페이지 주소를 돌려줍니다 – 앱 안의 웹 화면으로 띄우세요.
    @MainActor
    static func share(_ prescription: Prescription, cardImage: UIImage) async throws -> URL? {
        guard isConfigured else { throw ShareError.notConfigured }

        let imageURL = try await uploadImage(cardImage)
        let template = makeTemplate(prescription, imageURL: imageURL)

        if ShareApi.isKakaoTalkSharingAvailable() {
            let url = try await shareURL(template)
            guard await UIApplication.shared.open(url) else { throw ShareError.cannotOpen }
            return nil
        }

        // 카카오톡이 없는 기기(시뮬레이터 등) – 웹 공유 페이지
        guard let webURL = ShareApi.shared.makeDefaultUrl(templatable: template) else {
            throw ShareError.cannotOpen
        }
        return webURL
    }

    /// 카카오 SDK 오류를 사람이 읽을 수 있는 문장으로 (원인 파악용)
    static func describe(_ error: Error) -> String {
        guard let sdkError = error as? SdkError else { return error.localizedDescription }
        switch sdkError {
        case .ApiFailed(let reason, let info):
            return "카카오 API 오류 \(reason)\n\(info?.msg ?? "")"
        case .ClientFailed(let reason, let message):
            return "카카오 SDK 오류 \(reason)\n\(message ?? "")"
        case .AuthFailed(let reason, let info):
            return "카카오 인증 오류 \(reason)\n\(info?.errorDescription ?? "")"
        default:
            return error.localizedDescription
        }
    }

    // MARK: - 내부

    private static func makeTemplate(_ p: Prescription, imageURL: URL) -> FeedTemplate {
        // 앱이 설치되어 있으면 앱을 열고, 아니면 webURL로 이동
        let link = Link(
            webUrl: webURL,
            mobileWebUrl: webURL,
            androidExecutionParams: ["from": "kakao_share"],
            iosExecutionParams: ["from": "kakao_share"]
        )

        let description: String
        if let verse = p.verses.first {
            description = "\(verse.text.prefix(60))… (\(verse.reference))"
        } else {
            description = "오늘 나에게 꼭 맞는 말씀을 받아 보세요."
        }

        let content = Content(
            title: p.summary,
            imageUrl: imageURL,
            imageWidth: 720,
            imageHeight: 720,
            description: description,
            link: link
        )

        return FeedTemplate(
            content: content,
            buttons: [Button(title: "나도 말씀 처방 받기", link: link)]
        )
    }

    private static func uploadImage(_ image: UIImage) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            ShareApi.shared.imageUpload(image: image) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = result?.infos.original.url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.cannotOpen)
                }
            }
        }
    }

    private static func shareURL(_ template: FeedTemplate) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            ShareApi.shared.shareDefault(templatable: template) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = result?.url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.cannotOpen)
                }
            }
        }
    }
}
