// 모델별 최신 전체 실행 결과(quick 제외)를 비교해 results/compare.md로 저장합니다.
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const dir = fileURLToPath(new URL("./results/", import.meta.url));
const files = readdirSync(dir).filter((f) => f.endsWith(".json") && !f.includes("-quick")).sort();

// 파일 이름: 202610070139-claude-opus-5-5-low.json → 모델별로 가장 최근 것만
const latest = {};
for (const f of files) {
  const model = f.replace(/^\d+-/, "").replace(/\.json$/, "").replace(/-(low|medium|high|xhigh|max)$/, "");
  const runs = JSON.parse(readFileSync(dir + f, "utf8"));
  if (runs.length < 10) continue; // 한두 개짜리 시험 실행은 건너뜀
  latest[model] = { file: f, runs };
}

const avg = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);
const len = (s) => [...s].length;
const ref = (v) => `${v.book} ${v.chapter}:${v.verse_start}`;

const rows = [];
for (const [model, { file, runs }] of Object.entries(latest)) {
  const ok = runs.filter((r) => !r.error);
  const refs = ok.flatMap((r) => r.result.verses.map(ref));
  const counts = {};
  for (const x of refs) counts[x] = (counts[x] ?? 0) + 1;
  const top = Object.entries(counts).sort((a, b) => b[1] - a[1])[0] ?? ["-", 0];
  const krw = avg(ok.map((r) => r.krw));
  const c08 = ok.find((r) => r.id === "c08");
  rows.push({
    model, file,
    success: `${ok.length}/${runs.length}`,
    pass: ok.filter((r) => !r.checks.length).length,
    sec: avg(ok.map((r) => r.seconds)).toFixed(1),
    krw: krw.toFixed(1),
    month1: Math.round(krw * 30),
    month3: Math.round(krw * 90),
    unique: `${Object.keys(counts).length}/${refs.length}`,
    top: `${top[0]} (${top[1]}회)`,
    letter: Math.round(avg(ok.map((r) => len(r.result.letter)))),
    prayer: Math.round(avg(ok.map((r) => len(r.result.prayer)))),
    crisis: c08 ? (c08.result.crisis && c08.result.letter.includes("109") ? "✅" : "❌") : "-",
    issues: ok.flatMap((r) => r.checks.map((x) => `${r.id}: ${x}`)),
    byId: Object.fromEntries(ok.map((r) => [r.id, r.result])),
  });
}
rows.sort((a, b) => Number(a.krw) - Number(b.krw));

const L = [];
L.push("# 모델 비교", "");
L.push("| 항목 | " + rows.map((r) => r.model).join(" | ") + " |");
L.push("|---|" + rows.map(() => "---").join("|") + "|");
const line = (label, key) => L.push(`| ${label} | ` + rows.map((r) => r[key]).join(" | ") + " |");
line("성공", "success");
line("자동 점검 통과", "pass");
line("평균 응답 시간(초)", "sec");
line("1회 평균 비용(원)", "krw");
line("월 비용·하루 1회(원)", "month1");
line("월 비용·하루 3회(원)", "month3");
line("서로 다른 구절 수", "unique");
line("가장 많이 나온 구절", "top");
line("편지 평균 글자 수", "letter");
line("기도문 평균 글자 수", "prayer");
line("위기 대응(c08)", "crisis");
L.push("");
for (const r of rows) {
  if (r.issues.length) L.push(`- **${r.model}** 점검 경고: ${r.issues.join(" · ")}`);
}
L.push("");

// 같은 케이스를 나란히
for (const id of ["c01", "c07", "c08", "c13", "c20"]) {
  L.push(`---`, `## ${id}`, "");
  for (const r of rows) {
    const x = r.byId[id];
    if (!x) continue;
    L.push(`### ${r.model} — ${x.summary}`);
    L.push(`구절: ${x.verses.map(ref).join(", ")}${x.crisis ? " · 🚨 위기" : ""}`, "");
    L.push(x.letter, "");
  }
}

const out = fileURLToPath(new URL("./results/compare.md", import.meta.url));
writeFileSync(out, L.join("\n"));
console.log(L.slice(0, 16).join("\n"));
console.log(`\n자세한 비교: results/compare.md`);
