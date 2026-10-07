// 말씀 처방 프롬프트와 응답 스키마 (prompt-test/prompt.mjs에서 검증한 버전)

export const MODES = ["고민", "카테고리", "생년월일", "기도제목"] as const;
export type Mode = (typeof MODES)[number];

export type Verse = {
  book: string;
  chapter: number;
  verse_start: number;
  verse_end: number;
  text: string;
  why: string;
};

export type Prescription = {
  summary: string;
  verses: Verse[];
  letter: string;
  prayer: string;
  energy: { faith: number; hope: number; love: number; joy: number; peace: number };
  crisis: boolean;
};

export const SYSTEM_PROMPT = `당신은 "말씀의 위로" 앱의 말씀 처방사입니다.
사용자의 고민이나 기도 제목을 듣고, 그 사람에게 꼭 맞는 성경 말씀과 따뜻한 위로를 전합니다.

## 구절 고르기
- 구절은 사용자 메시지의 [후보 구절] 목록에서만 고릅니다. 목록에 없는 구절은 쓰지 않습니다.
- 먼저 사용자의 상황에 맞는 주제를 1~2개 정하고, 그 주제의 후보 중에서 이 사람의 사연에 가장 구체적으로 닿는 구절을 고릅니다.
- 누구에게나 쓸 수 있는 무난한 구절보다, 이 사람의 상황을 정확히 짚는 구절을 우선합니다.
- [최근 받은 구절]에 있는 구절은 고르지 않습니다.
- 범위로 적힌 후보(예: 빌립보서 4:6-7)는 그 범위 그대로 씁니다.

## 응답 원칙
- 구절 본문(text)은 개역개정 표현에 가깝게 적되, 기억이 확실하지 않으면 뜻을 해치지 않게 짧게 요약합니다. (본문은 앱에서 성경 DB로 다시 확인합니다.)
- 위로 편지는 사용자의 상황을 구체적으로 짚어 주고, 정죄하거나 훈계하지 않습니다. 하나님의 사랑과 동행을 중심에 둡니다.
- 기도문은 사용자가 그대로 소리 내어 읽을 수 있게 1인칭("저", "제가")으로 씁니다.
- 신앙이 없는 사용자도 거부감 없이 읽을 수 있는 쉬운 말을 씁니다. 교파 간 논쟁이 되는 교리는 다루지 않습니다.
- 운세, 점, 미래 예언처럼 들리는 표현은 쓰지 않습니다. 생년월일은 그 사람을 부르는 따뜻한 계기로만 쓰고, 날짜로 성격이나 운명을 풀이하지 않습니다.

## 영적 에너지 5지표
믿음·소망·사랑·기쁨·평안을 0~100 사이 정수로 매깁니다.
사용자가 지금 느끼는 상태를 글에서 읽어낸 값이며, 평가나 점수가 아니라 "오늘의 마음 날씨"입니다.

## 위기 신호
자해, 자살, 학대, 폭력 위험이 보이면 crisis를 true로 합니다.
crisis가 true이면 위로 편지 마지막 문단에 아래 연락처를 반드시 그대로 적습니다.
  · 자살예방상담전화 109 (24시간)
  · 위급한 상황이면 112 또는 119
사용자의 나이, 성별, 가족 관계를 짐작해서 말하지 않습니다.
정죄하지 말고, 지금 도움을 요청하는 것이 용기라는 점을 전합니다.

## 분량과 형식
- 구절: 1~3개
- 위로 편지: 400~700자, 3~4개 문단. 문단 사이에는 빈 줄을 넣습니다.
- 기도문: 200~400자. 비워 두지 않습니다.
- 한 줄 요약: 25자 이내 (결과 카드 제목으로 씁니다)`;

export function buildUserMessage(
  { mode, name, input }: { mode: Mode; name?: string; input: string },
  { pool, recent = [] }: { pool: string; recent?: string[] },
): string {
  const who = name ? `이름: ${name}\n` : "";
  const bodies: Record<Mode, string> = {
    고민: `${who}[고민 상담]\n${input}`,
    카테고리: `${who}[카테고리 처방]\n오늘 마음이 가는 주제: ${input}\n이 주제로 오늘의 말씀을 처방해 주세요.`,
    생년월일: `${who}[생년월일 처방]\n생년월일: ${input}\n이 사람에게 오늘 힘이 될 말씀을 처방해 주세요.`,
    기도제목: `${who}[기도 제목]\n${input}\n이 기도 제목으로 기도문을 중심으로 처방해 주세요.`,
  };
  return (
    bodies[mode] +
    `\n\n[후보 구절]\n${pool}` +
    (recent.length ? `\n\n[최근 받은 구절]\n${recent.join(", ")}` : "")
  );
}

// 구조화 출력 스키마 – iOS 앱의 Codable 모델과 1:1로 맞춥니다.
const score = { type: "integer", description: "0~100" };

export const RESULT_SCHEMA = {
  type: "object",
  properties: {
    summary: { type: "string", description: "결과 카드 제목, 25자 이내" },
    verses: {
      type: "array",
      description: "1~3개",
      items: {
        type: "object",
        properties: {
          book: { type: "string", description: "성경 책 이름, 후보 목록의 표기 그대로" },
          chapter: { type: "integer" },
          verse_start: { type: "integer" },
          verse_end: { type: "integer", description: "한 절이면 verse_start와 같게" },
          text: { type: "string" },
          why: { type: "string", description: "이 구절을 고른 이유, 한두 문장" },
        },
        required: ["book", "chapter", "verse_start", "verse_end", "text", "why"],
        additionalProperties: false,
      },
    },
    letter: { type: "string", description: "위로 편지 400~700자" },
    prayer: { type: "string", description: "1인칭 기도문 200~400자" },
    energy: {
      type: "object",
      properties: { faith: score, hope: score, love: score, joy: score, peace: score },
      required: ["faith", "hope", "love", "joy", "peace"],
      additionalProperties: false,
    },
    crisis: { type: "boolean", description: "자해·자살·학대·폭력 위험 신호가 있으면 true" },
  },
  required: ["summary", "verses", "letter", "prayer", "energy", "crisis"],
  additionalProperties: false,
};

// 안전장치: 위기 신호가 있는데 모델이 상담 연락처를 빠뜨리면 코드에서 반드시 붙입니다.
export const CRISIS_FOOTER =
  "\n\n지금 많이 힘드시다면 혼자 견디지 말고 꼭 연락해 주세요.\n" +
  "· 자살예방상담전화 109 (24시간)\n" +
  "· 위급한 상황이면 112 또는 119";

export function applySafety(result: Prescription): Prescription {
  if (result.crisis && !result.letter.includes("109")) {
    return { ...result, letter: result.letter + CRISIS_FOOTER };
  }
  return result;
}
