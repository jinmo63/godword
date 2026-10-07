// POST /api/prescribe – 말씀 처방
//
// 요청 헤더: X-Device-Id (앱이 처음 실행될 때 만든 고유 ID)
// 요청 본문: { "mode": "고민", "name": "민지", "input": "...", "recent": ["이사야 41:10"] }
// 응답: { summary, verses, letter, prayer, energy, crisis, usage: { used, limit, remaining } }
import Anthropic from "@anthropic-ai/sdk";
import { MODES, type Mode } from "@/lib/prompt";
import { prescribe, PrescribeError } from "@/lib/claude";
import { checkUsage, recordUsage, type Plan } from "@/lib/usage";

// Claude 응답에 10~20초 걸리므로 넉넉히 잡습니다
export const maxDuration = 60;

const MAX_INPUT = 500; // 입력 글자 수 제한 (비용·남용 방지)
const MAX_NAME = 20;
const MAX_RECENT = 10;

function error(status: number, code: string, message: string, extra: object = {}) {
  return Response.json({ error: code, message, ...extra }, { status });
}

export async function POST(request: Request) {
  // 앱 토큰: 배포 주소를 알아낸 다른 사람이 API 크레딧을 쓰지 못하게 막는 1차 장치
  // (APP_TOKEN 환경변수가 설정된 경우에만 검사)
  const appToken = process.env.APP_TOKEN;
  if (appToken && request.headers.get("x-app-token") !== appToken) {
    return error(401, "unauthorized", "허용되지 않은 요청입니다.");
  }

  const deviceId = request.headers.get("x-device-id")?.trim();
  if (!deviceId || deviceId.length > 100) {
    return error(400, "missing_device_id", "X-Device-Id 헤더가 필요합니다.");
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return error(400, "invalid_json", "요청 본문이 JSON이 아닙니다.");
  }
  const { mode, name, input, recent } = (body ?? {}) as Record<string, unknown>;

  if (typeof mode !== "string" || !MODES.includes(mode as Mode)) {
    return error(400, "invalid_mode", `mode는 ${MODES.join(", ")} 중 하나여야 합니다.`);
  }
  if (typeof input !== "string" || !input.trim()) {
    return error(400, "invalid_input", "input이 비어 있습니다.");
  }
  if ([...input].length > MAX_INPUT) {
    return error(400, "input_too_long", `input은 ${MAX_INPUT}자 이내로 입력해 주세요.`);
  }
  if (name !== undefined && (typeof name !== "string" || [...name].length > MAX_NAME)) {
    return error(400, "invalid_name", `name은 ${MAX_NAME}자 이내 문자열이어야 합니다.`);
  }
  if (mode === "생년월일" && !/^\d{4}-\d{2}-\d{2}$/.test(input.trim())) {
    return error(400, "invalid_birthdate", "생년월일은 YYYY-MM-DD 형식이어야 합니다.");
  }
  const recentList = Array.isArray(recent)
    ? recent.filter((x): x is string => typeof x === "string").slice(0, MAX_RECENT)
    : [];

  // TODO: 구독 결제(StoreKit 2)를 붙이면 서버에서 확인한 구독 상태로 plan을 정합니다.
  const plan: Plan = "free";
  const usage = checkUsage(deviceId, plan);
  if (!usage.allowed) {
    return error(429, "daily_limit", "오늘 무료 사용 횟수를 모두 사용했어요.", {
      usage: { used: usage.used, limit: usage.limit, remaining: 0 },
    });
  }

  try {
    const result = await prescribe({
      mode: mode as Mode,
      name: typeof name === "string" ? name.trim() : undefined,
      input: input.trim(),
      recent: recentList,
    });
    const used = recordUsage(usage.key);
    const { model, ...prescription } = result;
    console.log(`[prescribe] ${mode} ok model=${model} used=${used}/${usage.limit}`);
    return Response.json({
      ...prescription,
      usage: { used, limit: usage.limit, remaining: Math.max(usage.limit - used, 0) },
    });
  } catch (e) {
    if (e instanceof PrescribeError) {
      console.error(`[prescribe] ${e.code}: ${e.message}`);
      return error(502, e.code, "말씀을 준비하지 못했어요. 잠시 후 다시 시도해 주세요.");
    }
    if (e instanceof Anthropic.RateLimitError) {
      return error(503, "busy", "지금 요청이 많아요. 잠시 후 다시 시도해 주세요.");
    }
    if (e instanceof Anthropic.AuthenticationError) {
      console.error("[prescribe] ANTHROPIC_API_KEY가 올바르지 않습니다.");
      return error(500, "server_config", "서버 설정 오류입니다.");
    }
    if (e instanceof Anthropic.APIError) {
      console.error(`[prescribe] API ${e.status}: ${e.message}`);
      return error(502, "upstream", "말씀을 준비하지 못했어요. 잠시 후 다시 시도해 주세요.");
    }
    throw e;
  }
}
