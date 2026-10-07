// 말씀 처방 프롬프트 테스트 (기본: 가장 저렴한 Haiku 4.5)
//   npm run quick                    → 대표 케이스 6개만 (약 80원)
//   npm test                         → cases.json 전체 20개 (약 280원)
//   npm run one -- c08               → 한 케이스만 실행
//   npm test -- --model claude-sonnet-5-5   → 다른 모델로 실행
//   npm run compare                  → 모델별 최신 결과 비교표
import Anthropic from "@anthropic-ai/sdk";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { SYSTEM_PROMPT, RESULT_SCHEMA, buildUserMessage, applySafety } from "./prompt.mjs";
import { samplePool, ALL_KEYS, verseKey } from "./verses.mjs";

// ---- 설정 ----
const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] && !args[i + 1].startsWith("--") ? args[i + 1] : fallback;
};
const MODEL = arg("model", "claude-haiku-4-5");
const EFFORT = arg("effort", "low");
const LIMIT = Number(arg("limit", "0"));
const ONLY = arg("only", null);
const QUICK = args.includes("--quick");
// 모드별 대표 + 위기(c08) + 로또(c20)
const QUICK_IDS = ["c01", "c07", "c08", "c09", "c13", "c20"];
// Haiku 4.5는 effort 설정을 지원하지 않습니다
const SUPPORTS_EFFORT = !MODEL.startsWith("claude-haiku");
const CONCURRENCY = 3;
const KRW_PER_USD = 1400; // 환율 가정

// 1M 토큰당 달러 (입력, 출력)
const PRICES = {
  "claude-opus-5-5": [4, 20],
  "claude-sonnet-5-5": [2, 10],
  "claude-haiku-4-5": [1, 5],
};
// fallbacks: "default"는 이 모델들에서만 씁니다
const FALLBACK_MODELS = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-1", "claude-opus-5"];

if (!process.env.ANTHROPIC_API_KEY) {
  console.error("❌ .env 파일에 ANTHROPIC_API_KEY가 비어 있습니다. 키를 넣고 다시 실행하세요.");
  process.exit(1);
}

const client = new Anthropic();

// ---- 한 케이스 실행 ----
async function runCase(c) {
  const started = Date.now();
  const params = {
    model: MODEL,
    max_tokens: 16000,
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: buildUserMessage(c, { pool: samplePool(), recent: c.recent ?? [] }) }],
    output_config: {
      ...(SUPPORTS_EFFORT && { effort: EFFORT }),
      format: { type: "json_schema", schema: RESULT_SCHEMA },
    },
  };
  if (FALLBACK_MODELS.includes(MODEL)) {
    params.betas = ["server-side-fallback-2026-07-01"];
    params.fallbacks = "default";
  }

  const res = await client.beta.messages.create(params);
  const seconds = (Date.now() - started) / 1000;

  const [inPrice, outPrice] = PRICES[res.model] ?? PRICES[MODEL] ?? [0, 0];
  const usd = (res.usage.input_tokens * inPrice + res.usage.output_tokens * outPrice) / 1e6;
  const base = {
    id: c.id, mode: c.mode, input: c.input, seconds,
    servedBy: res.model, stop: res.stop_reason,
    inputTokens: res.usage.input_tokens, outputTokens: res.usage.output_tokens,
    krw: Math.round(usd * KRW_PER_USD * 10) / 10,
  };

  if (res.stop_reason === "refusal") {
    return { ...base, error: `거절됨 (${res.stop_details?.category ?? "분류 없음"})` };
  }
  if (res.stop_reason === "max_tokens") {
    return { ...base, error: "max_tokens에 걸려 응답이 잘림" };
  }

  const text = res.content.filter((b) => b.type === "text").map((b) => b.text).join("");
  let result;
  try {
    result = JSON.parse(text);
  } catch {
    return { ...base, error: "JSON 파싱 실패", raw: text };
  }
  result = applySafety(result);
  const checks = check(c, result);
  if (result.safetyAdded) checks.push("모델이 상담전화 누락 → 코드로 보완");
  return { ...base, result, checks };
}

// ---- 자동 점검 ----
function check(c, r) {
  const issues = [];
  const len = (s) => [...s].length;
  if (r.verses.length < 1 || r.verses.length > 3) issues.push(`구절 ${r.verses.length}개`);
  for (const v of r.verses) {
    if (v.verse_end < v.verse_start) issues.push(`구절 범위 오류 ${v.book} ${v.chapter}:${v.verse_start}-${v.verse_end}`);
    if (!ALL_KEYS.has(verseKey(v))) issues.push(`후보 밖 구절 ${verseKey(v)}`);
    if ((c.recent ?? []).some((x) => x.startsWith(verseKey(v)))) issues.push(`최근 구절 반복 ${verseKey(v)}`);
  }
  if (len(r.letter) < 300 || len(r.letter) > 900) issues.push(`편지 ${len(r.letter)}자`);
  if (len(r.prayer) < 150 || len(r.prayer) > 550) issues.push(`기도문 ${len(r.prayer)}자`);
  if (!r.letter.includes("\n\n")) issues.push("편지 문단 구분 없음");
  if (len(r.summary) > 30) issues.push(`요약 ${len(r.summary)}자`);
  for (const [k, v] of Object.entries(r.energy)) {
    if (v < 0 || v > 100) issues.push(`지표 ${k}=${v}`);
  }
  if (c.id === "c08" && !r.crisis) issues.push("위기 신호를 놓침");
  if (c.id === "c08" && !r.letter.includes("109")) issues.push("상담전화 안내 없음");
  if (c.id !== "c08" && r.crisis) issues.push("위기 아닌데 crisis=true");
  return issues;
}

// ---- 동시 실행 ----
async function runAll(cases) {
  const out = new Array(cases.length);
  let next = 0;
  async function worker() {
    while (next < cases.length) {
      const i = next++;
      const c = cases[i];
      try {
        out[i] = await runCase(c);
      } catch (e) {
        if (e instanceof Anthropic.AuthenticationError) {
          console.error("❌ API 키가 올바르지 않습니다. .env 파일을 확인하세요.");
          process.exit(1);
        } else if (e instanceof Anthropic.RateLimitError) {
          out[i] = { id: c.id, mode: c.mode, input: c.input, error: "요청 한도 초과(429) – 잠시 후 다시 실행" };
        } else if (e instanceof Anthropic.APIError) {
          out[i] = { id: c.id, mode: c.mode, input: c.input, error: `API 오류 ${e.status}: ${e.message}` };
        } else {
          throw e;
        }
      }
      const r = out[i];
      const mark = r.error ? "❌" : r.checks.length ? "⚠️ " : "✅";
      console.log(`${mark} ${c.id} [${c.mode}] ${r.seconds?.toFixed(1) ?? "-"}초 ${r.krw ?? "-"}원 ${r.error ?? r.checks.join(", ")}`);
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));
  return out;
}

// ---- 리포트 ----
function report(results) {
  const ok = results.filter((r) => !r.error);
  const avg = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);
  const avgKrw = avg(ok.map((r) => r.krw));
  const avgSec = avg(ok.map((r) => r.seconds));
  const lines = [];
  lines.push(`# 프롬프트 테스트 결과`);
  lines.push(``);
  lines.push(`- 실행: ${new Date().toLocaleString("ko-KR")}`);
  lines.push(`- 모델: ${MODEL} / effort: ${SUPPORTS_EFFORT ? EFFORT : "(지원 안 함)"}`);
  lines.push(`- 성공: ${ok.length} / ${results.length}, 자동 점검 통과: ${ok.filter((r) => !r.checks.length).length}`);
  lines.push(`- 평균 응답 시간: ${avgSec.toFixed(1)}초`);
  lines.push(`- 평균 비용: 1회 ${avgKrw.toFixed(1)}원 (환율 ${KRW_PER_USD}원 가정)`);
  lines.push(`- 월 비용 추정 (1인): 하루 1회 ${Math.round(avgKrw * 30)}원 · 하루 3회 ${Math.round(avgKrw * 90)}원 · 하루 20회 ${Math.round(avgKrw * 600)}원`);
  lines.push(``);
  for (const r of results) {
    lines.push(`---`);
    lines.push(`## ${r.id} · ${r.mode} — ${r.input}`);
    if (r.error) { lines.push(`**오류:** ${r.error}`); continue; }
    const x = r.result;
    lines.push(`*${r.seconds.toFixed(1)}초 · ${r.krw}원 · 응답 모델 ${r.servedBy}${r.checks.length ? ` · ⚠️ ${r.checks.join(", ")}` : ""}*`);
    lines.push(``);
    lines.push(`### ${x.summary}`);
    for (const v of x.verses) {
      const range = v.verse_end > v.verse_start ? `${v.verse_start}-${v.verse_end}` : `${v.verse_start}`;
      lines.push(`> **${v.book} ${v.chapter}:${range}** ${v.text}`);
      lines.push(`> — ${v.why}`);
      lines.push(``);
    }
    lines.push(`**위로 편지**`, ``, x.letter, ``, `**기도문**`, ``, x.prayer, ``);
    const e = x.energy;
    lines.push(`**5지표** 믿음 ${e.faith} · 소망 ${e.hope} · 사랑 ${e.love} · 기쁨 ${e.joy} · 평안 ${e.peace}${x.crisis ? " · 🚨 위기 신호" : ""}`);
    lines.push(``);
  }
  return { md: lines.join("\n"), avgKrw, avgSec, ok: ok.length };
}

// ---- 실행 ----
let cases = JSON.parse(readFileSync(new URL("./cases.json", import.meta.url), "utf8"));
const only = ONLY ?? (args[0] && !args[0].startsWith("--") ? args[0] : null);
if (only) cases = cases.filter((c) => c.id === only);
if (QUICK) cases = cases.filter((c) => QUICK_IDS.includes(c.id));
if (LIMIT > 0) cases = cases.slice(0, LIMIT);
if (!cases.length) { console.error("실행할 케이스가 없습니다."); process.exit(1); }

const [ip, op] = PRICES[MODEL] ?? [0, 0];
const estKrw = Math.round(cases.length * (2100 * ip + 1600 * op) / 1e6 * KRW_PER_USD);
console.log(`▶ ${cases.length}개 케이스 · ${MODEL}${SUPPORTS_EFFORT ? ` · effort ${EFFORT}` : ""} · 예상 비용 약 ${estKrw}원\n`);
const results = await runAll(cases);
const { md, avgKrw, avgSec, ok } = report(results);

mkdirSync(new URL("./results/", import.meta.url), { recursive: true });
const stamp = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, "");
const tag = `${stamp}-${MODEL}${SUPPORTS_EFFORT ? `-${EFFORT}` : ""}${QUICK ? "-quick" : ""}`;
const base = fileURLToPath(new URL(`./results/${tag}`, import.meta.url));
writeFileSync(`${base}.json`, JSON.stringify(results, null, 2));
writeFileSync(`${base}.md`, md);

console.log(`\n성공 ${ok}/${results.length} · 평균 ${avgSec.toFixed(1)}초 · 1회 평균 ${avgKrw.toFixed(1)}원`);
console.log(`결과: results/${tag}.md`);
