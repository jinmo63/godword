// 하루 사용 횟수 제한
//
// ⚠️ 지금은 서버 메모리에 저장합니다. 로컬 개발용으로는 충분하지만,
// Vercel처럼 여러 인스턴스가 뜨고 꺼지는 환경에서는 횟수가 초기화될 수 있습니다.
// 배포 전에 Supabase 같은 DB로 바꿉니다. (함수 모양은 그대로 두고 내부만 교체)

export type Plan = "free" | "basic" | "premium";

const LIMITS: Record<Plan, number> = {
  free: Number(process.env.FREE_DAILY_LIMIT ?? 3),
  basic: Number(process.env.BASIC_DAILY_LIMIT ?? 20),
  premium: Number.POSITIVE_INFINITY,
};

const counts = new Map<string, number>();

// 한국 시간 기준 날짜 (자정에 초기화)
function todayKST(): string {
  return new Date(Date.now() + 9 * 3600_000).toISOString().slice(0, 10);
}

export function checkUsage(userId: string, plan: Plan) {
  const key = `${todayKST()}:${userId}`;
  const used = counts.get(key) ?? 0;
  const limit = LIMITS[plan];
  return { key, used, limit, allowed: used < limit };
}

// 응답이 성공했을 때만 1회 차감합니다.
export function recordUsage(key: string): number {
  const used = (counts.get(key) ?? 0) + 1;
  counts.set(key, used);
  return used;
}
