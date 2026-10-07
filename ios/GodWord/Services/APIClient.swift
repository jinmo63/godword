import Foundation

/// 말씀의 위로 서버와 통신합니다.
/// Claude API 키는 서버에만 있고, 앱은 서버만 호출합니다.
struct APIClient {
    /// 기본 서버 주소: Config/Kakao.xcconfig의 GODWORD_SERVER_URL, 없으면 맥북 localhost
    static let defaultServerURL: String = {
        let configured = (Bundle.main.object(forInfoDictionaryKey: "GODWORD_SERVER_URL") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return configured.isEmpty ? "http://localhost:3000" : configured
    }()
    static let serverURLKey = "serverURL"

    var baseURL: URL {
        let saved = UserDefaults.standard.string(forKey: Self.serverURLKey) ?? ""
        return URL(string: saved.isEmpty ? Self.defaultServerURL : saved)
            ?? URL(string: Self.defaultServerURL)!
    }

    /// 앱 설치마다 한 번 만들어지는 기기 ID (하루 사용 횟수 계산용)
    static var deviceID: String {
        let key = "deviceID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    /// 서버의 APP_TOKEN과 같은 값 (Config/Kakao.xcconfig → Info.plist)
    static var appToken: String? {
        Bundle.main.object(forInfoDictionaryKey: "GODWORD_APP_TOKEN") as? String
    }

    struct PrescribeRequest: Encodable {
        let mode: String
        let name: String?
        let input: String
        let recent: [String]
    }

    struct ErrorBody: Decodable {
        let error: String
        let message: String
        let usage: Usage?
    }

    enum APIError: LocalizedError {
        case server(code: String, message: String, usage: Usage?)
        case network(String)
        case decoding

        var errorDescription: String? {
            switch self {
            case .server(_, let message, _): message
            case .network(let detail): "서버에 연결하지 못했어요.\n\(detail)"
            case .decoding: "응답을 읽지 못했어요. 잠시 후 다시 시도해 주세요."
            }
        }

        var isDailyLimit: Bool {
            if case .server("daily_limit", _, _) = self { return true }
            return false
        }
    }

    func prescribe(mode: Mode, name: String?, input: String, recent: [String]) async throws -> Prescription {
        var request = URLRequest(url: baseURL.appending(path: "api/prescribe"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60 // AI 응답에 10~20초 걸림
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.deviceID, forHTTPHeaderField: "X-Device-Id")
        request.setValue(Self.appToken, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try JSONEncoder().encode(
            PrescribeRequest(mode: mode.rawValue, name: name, input: input, recent: recent)
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw APIError.server(code: body.error, message: body.message, usage: body.usage)
            }
            throw APIError.network("HTTP \(status)")
        }

        do {
            return try JSONDecoder().decode(Prescription.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    struct Health: Decodable {
        let ok: Bool
        let model: String
        let hasApiKey: Bool
    }

    func health() async throws -> Health {
        var request = URLRequest(url: baseURL.appending(path: "api/health"))
        request.timeoutInterval = 5
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Health.self, from: data)
    }
}
