// 화면 흐름도(스토리보드) 이미지 생성기
// 실행: swift ios/tools/make_flow.swift docs/화면흐름 docs/화면흐름도.png
import AppKit

let dir = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]
let W: CGFloat = 2880, H: CGFloat = 1200

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let teal = color(0x1F6F78), ink = color(0x16202B), gray = color(0x5D6A79), line = color(0xD9E0E6)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
// 위에서 아래로 좌표 (y=0이 위)
let flipped = NSGraphicsContext(cgContext: gctx.cgContext, flipped: true)
NSGraphicsContext.current = flipped
let cg = flipped.cgContext
cg.translateBy(x: 0, y: H); cg.scaleBy(x: 1, y: -1)

color(0xFFFFFF).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

func font(_ size: CGFloat, bold: Bool = false) -> NSFont {
    NSFont(name: bold ? "AppleSDGothicNeo-Bold" : "AppleSDGothicNeo-Regular", size: size) ?? .systemFont(ofSize: size)
}
func text(_ s: String, center x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false, col: NSColor = ink) {
    let attr: [NSAttributedString.Key: Any] = [.font: font(size, bold: bold), .foregroundColor: col]
    let str = NSAttributedString(string: s, attributes: attr)
    str.draw(at: NSPoint(x: x - str.size().width / 2, y: y))
}
func textLeft(_ s: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false, col: NSColor = ink) {
    let attr: [NSAttributedString.Key: Any] = [.font: font(size, bold: bold), .foregroundColor: col]
    NSAttributedString(string: s, attributes: attr).draw(at: NSPoint(x: x, y: y))
}
func image(_ name: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, radius: CGFloat = 22) {
    guard let img = NSImage(contentsOfFile: "\(dir)/\(name)") else { print("missing \(name)"); return }
    let r = NSRect(x: x, y: y, width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    let path = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
    path.addClip()
    img.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
    let border = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
    border.lineWidth = 3; line.setStroke(); border.stroke()
}
func arrow(_ pts: [NSPoint], label: String? = nil, labelAt: NSPoint? = nil, dashed: Bool = false) {
    let p = NSBezierPath()
    p.move(to: pts[0]); for q in pts.dropFirst() { p.line(to: q) }
    p.lineWidth = 5; p.lineJoinStyle = .round
    if dashed { p.setLineDash([16, 10], count: 2, phase: 0) }
    teal.setStroke(); p.stroke()
    // 화살촉
    let a = pts[pts.count - 2], b = pts[pts.count - 1]
    let ang = atan2(b.y - a.y, b.x - a.x), len: CGFloat = 26, spread: CGFloat = .pi / 7
    let head = NSBezierPath()
    head.move(to: b)
    head.line(to: NSPoint(x: b.x - len * cos(ang - spread), y: b.y - len * sin(ang - spread)))
    head.line(to: NSPoint(x: b.x - len * cos(ang + spread), y: b.y - len * sin(ang + spread)))
    head.close(); teal.setFill(); head.fill()
    if let label, let at = labelAt {
        let attr: [NSAttributedString.Key: Any] = [.font: font(24, bold: true), .foregroundColor: teal]
        let s = NSAttributedString(string: label, attributes: attr)
        let sz = s.size()
        let bg = NSRect(x: at.x - sz.width / 2 - 12, y: at.y - 4, width: sz.width + 24, height: sz.height + 8)
        color(0xFFFFFF).setFill(); NSBezierPath(roundedRect: bg, xRadius: 10, yRadius: 10).fill()
        s.draw(at: NSPoint(x: at.x - sz.width / 2, y: at.y))
    }
}

// 휴대폰 크기 (1206 x 2622 비율)
let ph: CGFloat = 420, pw: CGFloat = ph * 1206 / 2622
let row1: CGFloat = 70, row2: CGFloat = 680

// ── 1행: 첫 실행 → 하단 탭 4개
let onb: [(String, String, String, CGFloat)] = [
    ("01_소개.png", "소개", "앱 소개 · 시작하기", 70),
    ("02_동의.png", "이용 동의", "필수 동의 4개", 400),
]
for o in onb {
    image(o.0, x: o.3, y: row1, w: pw, h: ph)
    text(o.1, center: o.3 + pw / 2, y: row1 + ph + 12, size: 30, bold: true)
    text(o.2, center: o.3 + pw / 2, y: row1 + ph + 52, size: 22, col: gray)
}
textLeft("첫 실행 (한 번만)", x: 70, y: 18, size: 26, bold: true, col: teal)
arrow([NSPoint(x: 70 + pw + 14, y: row1 + ph / 2), NSPoint(x: 400 - 14, y: row1 + ph / 2)])

// 하단 탭 묶음
let boxX: CGFloat = 760, boxW: CGFloat = W - boxX - 50
let tabBox = NSRect(x: boxX, y: 10, width: boxW, height: row1 + ph + 100)
let tb = NSBezierPath(roundedRect: tabBox, xRadius: 28, yRadius: 28)
color(0x1F6F78, 0.05).setFill(); tb.fill()
tb.lineWidth = 3; color(0x1F6F78, 0.5).setStroke(); tb.stroke()
textLeft("하단 탭 4개 (TabView)", x: boxX + 30, y: 18, size: 26, bold: true, col: teal)
arrow([NSPoint(x: 400 + pw + 14, y: row1 + ph / 2), NSPoint(x: boxX - 6, y: row1 + ph / 2)],
      label: "동의", labelAt: NSPoint(x: (400 + pw + boxX) / 2, y: row1 + ph / 2 - 50))

let tabs: [(String, String, String)] = [
    ("03_오늘.png", "오늘", "최근 말씀 · 듣기 · 바로가기"),
    ("04_처방.png", "처방", "처방 방식 4가지"),
    ("05_내기록.png", "내 기록", "기록 · 저장한 말씀 · 마음 날씨"),
    ("09_나.png", "나", "내 정보 · 글씨 크기 · 동의"),
]
let gap = (boxW - 4 * pw) / 4
var tabCX: [CGFloat] = []
for (i, t) in tabs.enumerated() {
    let x = boxX + gap / 2 + CGFloat(i) * (pw + gap)
    tabCX.append(x + pw / 2)
    image(t.0, x: x, y: row1, w: pw, h: ph)
    text(t.1, center: x + pw / 2, y: row1 + ph + 12, size: 30, bold: true)
    text(t.2, center: x + pw / 2, y: row1 + ph + 52, size: 22, col: gray)
}

// ── 2행: 처방 흐름
let inX: CGFloat = 900, loadX: CGFloat = 1330
let resX = tabCX[2] - pw / 2          // 내 기록 바로 아래
let cardW: CGFloat = 400, cardH = cardW * 859 / 1080
let cardX = resX + pw + 150, cardY = row2 + (ph - cardH) / 2 - 20
let flow: [(String, String, String, CGFloat)] = [
    ("06_입력.png", "입력", "고민 · 이름은 \"나\"에서", inX),
    ("07_로딩.png", "AI 생성 중", "10~20초", loadX),
    ("08_결과.png", "결과", "말씀 · 편지 · 기도문", resX),
]
for f in flow {
    image(f.0, x: f.3, y: row2, w: pw, h: ph)
    text(f.1, center: f.3 + pw / 2, y: row2 + ph + 12, size: 30, bold: true)
    text(f.2, center: f.3 + pw / 2, y: row2 + ph + 52, size: 22, col: gray)
}
image("10_공유카드.png", x: cardX, y: cardY, w: cardW, h: cardH, radius: 16)
text("공유 카드", center: cardX + cardW / 2, y: cardY + cardH + 12, size: 30, bold: true)
text("카카오톡 · 다른 앱", center: cardX + cardW / 2, y: cardY + cardH + 52, size: 22, col: gray)

let midY = row2 + ph / 2
arrow([NSPoint(x: inX + pw + 14, y: midY), NSPoint(x: loadX - 14, y: midY)])
arrow([NSPoint(x: loadX + pw + 14, y: midY), NSPoint(x: resX - 14, y: midY)])
arrow([NSPoint(x: resX + pw + 14, y: midY), NSPoint(x: cardX - 14, y: midY)],
      label: "공유", labelAt: NSPoint(x: (resX + pw + cardX) / 2, y: midY - 50))

// 탭 → 처방 흐름 연결선
let busY: CGFloat = 625, inCX = inX + pw / 2, top1 = row1 + ph + 92
arrow([NSPoint(x: tabCX[0], y: top1), NSPoint(x: tabCX[0], y: busY), NSPoint(x: inCX, y: busY), NSPoint(x: inCX, y: row2 - 10)])
arrow([NSPoint(x: tabCX[1], y: top1), NSPoint(x: tabCX[1], y: busY), NSPoint(x: inCX, y: busY)],
      label: "처방 방식 선택", labelAt: NSPoint(x: (tabCX[1] + inCX) / 2 + 60, y: busY - 18))
arrow([NSPoint(x: tabCX[2], y: top1), NSPoint(x: tabCX[2], y: row2 - 10)],
      label: "기록 보기", labelAt: NSPoint(x: tabCX[2] + 110, y: busY - 18))

// 왼쪽 설명
textLeft("말씀 처방 흐름", x: 70, y: row2 + 20, size: 34, bold: true, col: teal)
let notes = [
    "• 오늘 · 처방 탭에서 처방 방식을 고르면",
    "   입력 → AI 생성 → 결과 순서로 진행",
    "• 결과는 \"내 기록\"에 자동 저장",
    "• 모든 하위 화면의 홈 버튼을 누르면",
    "   \"오늘\" 탭 첫 화면으로 바로 이동",
    "• 위기 신호가 있으면 결과 맨 위에",
    "   109 상담전화 안내",
]
for (i, n) in notes.enumerated() {
    textLeft(n, x: 70, y: row2 + 90 + CGFloat(i) * 46, size: 25, col: ink)
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("✓ \(outPath)")
