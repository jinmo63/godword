# 말씀의 위로 (GodWord)

고민이나 기도 제목을 입력하면 AI(Claude)가 성경 말씀·위로 편지·기도문을 처방해 주는 iOS 앱.

| 폴더 | 내용 |
|---|---|
| `ios/` | SwiftUI 앱 (iOS 17+) |
| `server/` | Next.js API 서버 (`POST /api/prescribe`) – 자세한 내용은 `server/README.md` |
| `prompt-test/` | 프롬프트·모델 비교 테스트 스크립트 |
| `tools/` | 개발 도구 (cloudflared는 저장소에 포함하지 않음) |

## 처음 설정 (비밀 값은 저장소에 없음)

1. `server/.env.example` → `server/.env.local`로 복사하고 `ANTHROPIC_API_KEY`, `APP_TOKEN` 입력
2. `prompt-test/.env.example` → `prompt-test/.env`로 복사하고 `ANTHROPIC_API_KEY` 입력
3. `ios/Config/Kakao.xcconfig.example` → `ios/Config/Kakao.xcconfig`로 복사하고 카카오 네이티브 앱 키, `APP_TOKEN`과 같은 값, 서버 주소 입력
4. `cd server && npm install && npm run dev`
5. Xcode로 `ios/GodWord.xcodeproj`를 열고 실행
