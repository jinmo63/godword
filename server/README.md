# 말씀의 위로 API 서버

iOS 앱이 호출하는 서버입니다. Claude API 키는 이 서버에만 있고, 앱에는 넣지 않습니다.

## 실행

```bash
npm run dev      # 개발 모드 (코드를 고치면 바로 반영)
npm run build && npm start   # 배포와 같은 모드
```

`http://localhost:3000/api/health`에서 `"ok": true`가 보이면 정상입니다.

## 환경변수 (`.env.local`)

| 이름 | 설명 |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic API 키 |
| `CLAUDE_MODEL` | 개발: `claude-haiku-4-5` (1회 약 13원) / 배포: `claude-sonnet-5-5` (1회 약 28원) |
| `FREE_DAILY_LIMIT` | 무료 사용자 하루 횟수 (기본 3) |
| `BASIC_DAILY_LIMIT` | 베이직 하루 횟수 (기본 20) |

## API

### `POST /api/prescribe`

헤더: `Content-Type: application/json`, `X-Device-Id: <앱이 만든 고유 ID>`

```json
{
  "mode": "고민",
  "name": "민지",
  "input": "취업 준비 2년째인데 또 떨어졌어요.",
  "recent": ["이사야 41:10"]
}
```

| 필드 | 필수 | 설명 |
|---|---|---|
| `mode` | ✅ | `고민` · `카테고리` · `생년월일` · `기도제목` |
| `input` | ✅ | 500자 이내. 생년월일 모드는 `YYYY-MM-DD` |
| `name` | | 20자 이내 |
| `recent` | | 최근 받은 구절 (최대 10개). 이 구절은 다시 고르지 않음 |

성공 응답 (200):

```json
{
  "summary": "결과 카드 제목",
  "verses": [{ "book": "시편", "chapter": 27, "verse_start": 10, "verse_end": 10, "text": "...", "why": "..." }],
  "letter": "위로 편지",
  "prayer": "기도문",
  "energy": { "faith": 35, "hope": 40, "love": 55, "joy": 25, "peace": 30 },
  "crisis": false,
  "usage": { "used": 1, "limit": 3, "remaining": 2 }
}
```

오류 응답: `{ "error": "코드", "message": "사용자에게 보여줄 문장" }`

| HTTP | error | 의미 |
|---|---|---|
| 400 | `missing_device_id` `invalid_mode` `invalid_input` `input_too_long` `invalid_name` `invalid_birthdate` `invalid_json` | 요청이 잘못됨 |
| 429 | `daily_limit` | 오늘 횟수를 다 씀 (`usage` 포함) |
| 502 | `refused` `truncated` `bad_output` `upstream` | AI 응답 실패 – 다시 시도 |
| 503 | `busy` | 요청이 많음 – 잠시 후 다시 시도 |

### `GET /api/health`

서버 상태 확인. Claude를 호출하지 않으므로 비용이 들지 않습니다.

## 안전장치

- 후보 목록(`lib/verses.ts`)에 없는 구절은 응답에서 뺍니다.
- `crisis`가 `true`인데 상담전화가 없으면 109·112·119 안내를 코드에서 붙입니다.
- 횟수는 응답이 성공했을 때만 차감합니다.

## 배포 전에 할 일

- [ ] 사용 횟수를 메모리 대신 Supabase에 저장 (`lib/usage.ts`) – 지금은 서버가 재시작되면 초기화됨
- [ ] StoreKit 2 구독 상태를 서버에서 확인해 `plan` 정하기 (`app/api/prescribe/route.ts`의 TODO)
- [ ] 성경 DB 연결: 구절 본문(`text`)을 DB의 본문으로 교체
- [ ] Vercel 환경변수에 `ANTHROPIC_API_KEY`, `CLAUDE_MODEL=claude-sonnet-5-5` 등록
- [ ] Anthropic 콘솔에서 월 사용 한도 설정
