import Foundation

/// 내 정보 – "나" 탭에서 한 번만 입력하고, 처방할 때마다 다시 묻지 않습니다.
/// 이 기기에만 저장되며, 처방을 요청할 때만 서버로 보냅니다.
enum Profile {
    static let nameKey = "profileName"
    /// 생년월일 (1970년 기준 초 – 1970년 이전 날짜는 음수)
    static let birthdateKey = "profileBirthdate"
    /// 생년월일을 저장했는지 여부 (값이 0이거나 음수여도 저장된 것으로 판단하기 위해 따로 둠)
    static let hasBirthdateKey = "profileHasBirthdate"
    static let nameLimit = 20

    /// 생년월일을 한 번이라도 입력했는지 (숨겨도 값은 남아 있음)
    static var hasStoredBirthdate: Bool {
        UserDefaults.standard.object(forKey: birthdateKey) != nil
    }

    /// 저장된 생년월일, 없으면 기본값
    static var storedOrDefaultBirthdate: Date {
        hasStoredBirthdate
            ? Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: birthdateKey))
            : defaultBirthdate
    }

    static var defaultBirthdate: Date {
        Calendar.current.date(from: DateComponents(year: 1980, month: 1, day: 1)) ?? .now
    }

    static func birthdateText(_ seconds: Double) -> String {
        Date(timeIntervalSince1970: seconds).formatted(date: .long, time: .omitted)
    }

    /// 서버로 보내는 형식 (YYYY-MM-DD)
    static func birthdateValue(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
