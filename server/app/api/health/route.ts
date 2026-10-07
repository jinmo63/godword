import { connection } from "next/server";

// GET /api/health – 서버가 살아 있는지 확인 (Claude는 호출하지 않음)
export async function GET() {
  await connection(); // 빌드 때 미리 만들지 않고 요청마다 실행
  return Response.json({
    ok: true,
    model: process.env.CLAUDE_MODEL ?? "claude-sonnet-5-5",
    hasApiKey: Boolean(process.env.ANTHROPIC_API_KEY),
  });
}
