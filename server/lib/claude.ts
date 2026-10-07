import Anthropic from "@anthropic-ai/sdk";
import {
  SYSTEM_PROMPT,
  RESULT_SCHEMA,
  buildUserMessage,
  applySafety,
  type Mode,
  type Prescription,
} from "./prompt";
import { samplePool, ALL_KEYS, verseKey } from "./verses";

// API 키는 서버 환경변수(ANTHROPIC_API_KEY)에서만 읽습니다. 앱에는 절대 넣지 않습니다.
const client = new Anthropic();

const MODEL = process.env.CLAUDE_MODEL ?? "claude-sonnet-5-5";
// Haiku 4.5는 effort 설정을 지원하지 않습니다
const SUPPORTS_EFFORT = !MODEL.startsWith("claude-haiku");
// 거절 시 자동 대체 모델(fallbacks: "default")은 이 모델들에서만 씁니다
const FALLBACK_MODELS = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-1", "claude-opus-5"];

export class PrescribeError extends Error {
  constructor(
    public code: "refused" | "truncated" | "bad_output",
    message: string,
  ) {
    super(message);
  }
}

export async function prescribe(req: {
  mode: Mode;
  name?: string;
  input: string;
  recent?: string[];
}): Promise<Prescription & { model: string }> {
  const useFallback = FALLBACK_MODELS.includes(MODEL);

  const res = await client.beta.messages.create({
    model: MODEL,
    max_tokens: 16000,
    system: SYSTEM_PROMPT,
    messages: [
      { role: "user", content: buildUserMessage(req, { pool: samplePool(), recent: req.recent }) },
    ],
    output_config: {
      ...(SUPPORTS_EFFORT && { effort: "low" as const }),
      format: { type: "json_schema", schema: RESULT_SCHEMA },
    },
    ...(useFallback && {
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default" as const,
    }),
  });

  if (res.stop_reason === "refusal") {
    throw new PrescribeError("refused", `refusal: ${res.stop_details?.category ?? "unknown"}`);
  }
  if (res.stop_reason === "max_tokens") {
    throw new PrescribeError("truncated", "max_tokens");
  }

  const text = res.content
    .filter((b) => b.type === "text")
    .map((b) => b.text)
    .join("");

  let result: Prescription;
  try {
    result = JSON.parse(text);
  } catch {
    throw new PrescribeError("bad_output", "JSON parse failed");
  }

  // 후보 목록에 없는 구절은 버립니다 (지어낸 구절 차단)
  const verses = result.verses.filter((v) => ALL_KEYS.has(verseKey(v)));
  if (verses.length === 0) {
    throw new PrescribeError("bad_output", "no valid verses");
  }

  return { ...applySafety({ ...result, verses }), model: res.model };
}
