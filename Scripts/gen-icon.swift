#!/usr/bin/env swift
// 앱 아이콘을 렌더링해 Resources/AppIcon.icns를 만든다.
//
// 모티프: 키캡 위에 돋보기 — "어떤 키를 누가 가져갔나"를 찾는 앱.
// 16pt에서도 읽히도록 요소를 둘로만 제한하고, 돋보기 테두리를 굵게 둔다.
//
// 사용법:  swift Scripts/gen-icon.swift

import AppKit

let outDir = "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

/// 한 변이 `size`인 아이콘을 그린다. 모든 좌표는 1024 기준으로 두고 비율로 환산한다.
func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size / 1024   // 1024 기준 → 실제 크기

    // 32pt 이하에서는 요소 셋이 서로 뭉개진다. 키캡 하이라이트를 빼고, 렌즈와 테두리를
    // 키워 "키캡 + 돋보기" 두 덩어리로만 읽히게 한다.
    let small = size < 64

    // 배경: macOS 아이콘 관례인 둥근 사각형. 세로 그라디언트로 살짝 입체감만.
    let inset = 44 * s
    let bgRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 200 * s, cornerHeight: 200 * s, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let top = CGColor(red: 0.13, green: 0.16, blue: 0.22, alpha: 1)      // 짙은 슬레이트
    let bottom = CGColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1)
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    // 키캡: 살짝 왼쪽 위로 치우쳐 돋보기가 겹칠 자리를 남긴다.
    let capRect = small
        ? CGRect(x: 200 * s, y: 380 * s, width: 420 * s, height: 420 * s)
        : CGRect(x: 250 * s, y: 330 * s, width: 420 * s, height: 420 * s)
    let capPath = CGPath(roundedRect: capRect, cornerWidth: 88 * s, cornerHeight: 88 * s, transform: nil)
    ctx.addPath(capPath)
    ctx.setFillColor(CGColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1))
    ctx.fillPath()
    // 키캡 윗면 하이라이트 — 실제 키캡의 경사면을 암시한다. 작은 크기에서는 노이즈라 생략.
    if !small {
        let topFace = CGRect(x: 290 * s, y: 560 * s, width: 340 * s, height: 150 * s)
        ctx.addPath(CGPath(roundedRect: topFace, cornerWidth: 56 * s, cornerHeight: 56 * s, transform: nil))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.55))
        ctx.fillPath()
    }

    // 키캡 위의 ⌘ — 작은 크기에서는 뭉개지므로 128pt 이상에서만 그린다.
    if size >= 128 {
        let glyph = "⌘" as NSString
        let font = NSFont.systemFont(ofSize: 230 * s, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.26, alpha: 1),
        ]
        let bounds = glyph.size(withAttributes: attrs)
        glyph.draw(at: CGPoint(x: capRect.midX - bounds.width / 2,
                               y: capRect.midY - bounds.height / 2), withAttributes: attrs)
    }

    // 돋보기: 오른쪽 아래에서 키캡을 덮는다. 테두리를 굵게 해 16pt에서도 원으로 읽히게 한다.
    let lensCenter = small ? CGPoint(x: 660 * s, y: 330 * s) : CGPoint(x: 660 * s, y: 360 * s)
    let lensRadius = small ? 250 * s : 190 * s
    let ring = small ? 95 * s : 58 * s

    // 손잡이 — 링과 같은 색, 45도 방향
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(ring * 0.95)
    ctx.setStrokeColor(CGColor(red: 0.99, green: 0.76, blue: 0.20, alpha: 1))   // 앰버
    let handleStart = CGPoint(x: lensCenter.x + lensRadius * 0.72, y: lensCenter.y - lensRadius * 0.72)
    let handleEnd = CGPoint(x: lensCenter.x + lensRadius * 1.55, y: lensCenter.y - lensRadius * 1.55)
    ctx.move(to: handleStart)
    ctx.addLine(to: handleEnd)
    ctx.strokePath()
    ctx.restoreGState()

    // 렌즈 유리 — 배경이 비치도록 반투명
    ctx.addEllipse(in: CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius,
                              width: lensRadius * 2, height: lensRadius * 2))
    ctx.setFillColor(CGColor(red: 0.62, green: 0.82, blue: 1.0, alpha: small ? 0.45 : 0.30))
    ctx.fillPath()

    // 렌즈 테두리
    ctx.addEllipse(in: CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius,
                              width: lensRadius * 2, height: lensRadius * 2))
    ctx.setLineWidth(ring)
    ctx.setStrokeColor(CGColor(red: 0.99, green: 0.76, blue: 0.20, alpha: 1))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// iconset이 요구하는 크기 전부
let specs: [(name: String, px: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for spec in specs {
    let rep = drawIcon(size: spec.px)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("PNG 인코딩 실패: \(spec.name)\n".data(using: .utf8)!)
        exit(1)
    }
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(spec.name).png"))
}
FileHandle.standardError.write("iconset 생성: \(specs.count)개 크기 → \(outDir)\n".data(using: .utf8)!)
