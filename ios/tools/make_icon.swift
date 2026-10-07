// 앱 아이콘 생성기 – 펼친 성경 위로 따뜻한 빛이 비치는 모양
// 실행: swift ios/tools/make_icon.swift ios/GodWord/Assets.xcassets/AppIcon.appiconset
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

struct Palette {
    let bgTop: UInt32, bgBottom: UInt32, glow: UInt32, glowAlpha: CGFloat
    let page: UInt32, pageShade: UInt32, line: UInt32, star: UInt32
}

let light = Palette(bgTop: 0x2E8F98, bgBottom: 0x124A52, glow: 0xFFE3A3, glowAlpha: 0.55,
                    page: 0xFFFAF0, pageShade: 0xEADFC8, line: 0xC9D9DA, star: 0xFFD27A)
let dark = Palette(bgTop: 0x1B2A2E, bgBottom: 0x0B1416, glow: 0xFFD27A, glowAlpha: 0.35,
                   page: 0xF3EBDD, pageShade: 0xD6C9AF, line: 0xB5C4C6, star: 0xFFC95C)

func draw(_ p: Palette, to path: String) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    // 알파 없는 RGB (App Store 아이콘은 투명도가 있으면 안 됨)
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // 좌표를 위에서 아래로 (y=0이 위)
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)
    let s = size

    // 1) 배경 그라데이션
    let bg = CGGradient(colorsSpace: cs, colors: [rgb(p.bgTop), rgb(p.bgBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: 0, y: s), options: [])

    // 2) 책 위의 따뜻한 빛
    let glow = CGGradient(colorsSpace: cs,
                          colors: [rgb(p.glow, p.glowAlpha), rgb(p.glow, 0)] as CFArray,
                          locations: [0, 1])!
    let glowCenter = CGPoint(x: s * 0.5, y: s * 0.40)
    ctx.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0,
                           endCenter: glowCenter, endRadius: s * 0.42, options: [])

    // 3) 펼친 책 – 왼쪽 페이지를 그리고 좌우 대칭으로 오른쪽 페이지
    let spineTop = CGPoint(x: s * 0.5, y: s * 0.47)
    let spineBottom = CGPoint(x: s * 0.5, y: s * 0.76)
    let outerTop = CGPoint(x: s * 0.17, y: s * 0.43)
    let outerBottom = CGPoint(x: s * 0.17, y: s * 0.71)

    func page(mirrored: Bool) -> CGPath {
        func m(_ pt: CGPoint) -> CGPoint { mirrored ? CGPoint(x: s - pt.x, y: pt.y) : pt }
        let path = CGMutablePath()
        path.move(to: m(spineBottom))
        path.addLine(to: m(spineTop))
        // 위쪽 가장자리: 가운데가 살짝 내려앉은 곡선
        path.addCurve(to: m(outerTop),
                      control1: m(CGPoint(x: s * 0.42, y: s * 0.39)),
                      control2: m(CGPoint(x: s * 0.26, y: s * 0.38)))
        path.addLine(to: m(outerBottom))
        path.addCurve(to: m(spineBottom),
                      control1: m(CGPoint(x: s * 0.26, y: s * 0.66)),
                      control2: m(CGPoint(x: s * 0.42, y: s * 0.68)))
        path.closeSubpath()
        return path
    }

    // 책 그림자
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.04, color: rgb(0x000000, 0.28))
    for mirrored in [false, true] {
        ctx.addPath(page(mirrored: mirrored))
        ctx.setFillColor(rgb(p.page))
        ctx.fillPath()
    }
    ctx.restoreGState()

    // 가운데 접힌 부분 음영
    for mirrored in [false, true] {
        ctx.saveGState()
        ctx.addPath(page(mirrored: mirrored))
        ctx.clip()
        let shade = CGGradient(colorsSpace: cs,
                               colors: [rgb(p.pageShade, 0.9), rgb(p.pageShade, 0)] as CFArray,
                               locations: [0, 1])!
        let x0 = s * 0.5
        let x1 = mirrored ? s * 0.58 : s * 0.42
        ctx.drawLinearGradient(shade, start: CGPoint(x: x0, y: 0), end: CGPoint(x: x1, y: 0), options: [])
        ctx.restoreGState()
    }

    // 페이지의 글줄
    ctx.setStrokeColor(rgb(p.line))
    ctx.setLineWidth(s * 0.012)
    ctx.setLineCap(.round)
    for i in 0..<4 {
        let t = CGFloat(i)
        let yOuter = s * (0.50 + t * 0.045)
        let yInner = yOuter + s * 0.035
        for mirrored in [false, true] {
            let xa = mirrored ? s - s * 0.235 : s * 0.235
            let xb = mirrored ? s - s * 0.44 : s * 0.44
            ctx.move(to: CGPoint(x: xa, y: yOuter))
            ctx.addQuadCurve(to: CGPoint(x: xb, y: yInner),
                             control: CGPoint(x: (xa + xb) / 2, y: yOuter - s * 0.004))
        }
    }
    ctx.strokePath()

    // 4) 책 위의 반짝이는 빛 (네 갈래 별)
    func sparkle(center c: CGPoint, r: CGFloat) {
        let path = CGMutablePath()
        let w = r * 0.22
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + w, y: c.y - w))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + w, y: c.y + w))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - w, y: c.y + w))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - w, y: c.y - w))
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: r * 0.6, color: rgb(p.star, 0.8))
        ctx.addPath(path)
        ctx.setFillColor(rgb(p.star))
        ctx.fillPath()
        ctx.restoreGState()
    }
    sparkle(center: CGPoint(x: s * 0.5, y: s * 0.235), r: s * 0.105)
    sparkle(center: CGPoint(x: s * 0.66, y: s * 0.17), r: s * 0.035)
    sparkle(center: CGPoint(x: s * 0.35, y: s * 0.20), r: s * 0.025)

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("✓ \(path)")
}

draw(light, to: "\(outDir)/AppIcon.png")
draw(dark, to: "\(outDir)/AppIcon-dark.png")
