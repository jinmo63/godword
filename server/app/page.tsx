export default function Home() {
  return (
    <main style={{ padding: 32, fontFamily: "system-ui, sans-serif", lineHeight: 1.6 }}>
      <h1>말씀의 위로 API 서버</h1>
      <ul>
        <li>
          <code>GET /api/health</code> – 서버 상태 확인
        </li>
        <li>
          <code>POST /api/prescribe</code> – 말씀 처방
        </li>
      </ul>
    </main>
  );
}
