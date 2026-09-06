#!/usr/bin/env swift
// 소셜 카드용 이미지를 만든다: docs/images/og-image.png (1200×630)
//
// og:image로 스크린샷(720×678)을 그대로 쓰고 있었다. 소셜 카드의 표준 비율은 1.91:1이라
// 세로로 잘리거나 작게 표시된다 — 홍보가 목적인 페이지에서 링크를 공유했을 때의 첫인상이
// 바로 이 이미지다. 사이트와 같은 팔레트로 카드를 따로 그린다.
//
// 사용법:  swift Scripts/gen-og-image.swift

import AppKit

let W: CGFloat = 1200, H: CGFloat = 630
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// 배경 — 사이트의 --bg(#0d1117)에서 --bg2(#161b22)로 옅게
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    CGColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1),
    CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

// 오른쪽: 판정 화면을 둥근 카드로. 오른쪽 끝으로 살짝 흘려보내 잘린 느낌을 준다.
if let shot = NSImage(contentsOfFile: "docs/images/verdict.png") {
    let cardW: CGFloat = 470
    let scale = cardW / shot.size.width
    let cardH = shot.size.height * scale
    let rect = CGRect(x: W - cardW - 56, y: (H - cardH) / 2, width: cardW, height: cardH)
    ctx.saveGState()
    let path = CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 44,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))
    ctx.addPath(path); ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    shot.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    ctx.restoreGState()
    // 테두리
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(red: 0.188, green: 0.212, blue: 0.239, alpha: 1))
    ctx.setLineWidth(1); ctx.strokePath()
}

// 왼쪽: 아이콘 + 제목 + 한 줄 설명.
// 좌표계 원점이 좌하단이라 위에서부터 쌓으려면 상단 y를 기준으로 잡아야 한다
// (예전엔 rect 높이를 글자 크기의 4배로 두고 아래를 기준 삼아 아이콘과 제목이 겹쳤다).
let left: CGFloat = 64
var top: CGFloat = H - 132   // 좌우 세로 중심을 맞춘다

if let icon = NSImage(contentsOfFile: "docs/images/icon.png") {
    icon.draw(in: CGRect(x: left, y: top - 92, width: 92, height: 92))
    top -= 92 + 30
}

/// `top`을 텍스트 상단으로 삼아 그리고, 실제로 차지한 높이를 돌려준다.
func draw(_ s: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight,
          color: NSColor, width: CGFloat) -> CGFloat {
    let style = NSMutableParagraphStyle(); style.lineSpacing = size * 0.14
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: style,
    ]
    let bounds = (s as NSString).boundingRect(
        with: CGSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin], attributes: attrs)
    let h = ceil(bounds.height)
    (s as NSString).draw(with: CGRect(x: left, y: top - h, width: width, height: h),
                         options: [.usesLineFragmentOrigin], attributes: attrs)
    return h
}

top -= draw("HotkeyDetective", top: top, size: 44, weight: .bold,
            color: .init(red: 0.902, green: 0.929, blue: 0.953, alpha: 1), width: 540) + 26
top -= draw("Find out which app stole\nyour keyboard shortcut", top: top, size: 37, weight: .semibold,
            color: .init(red: 0.941, green: 0.533, blue: 0.243, alpha: 1), width: 540) + 26
_ = draw("Free · Open source · macOS 14+ · 15 languages", top: top, size: 19, weight: .regular,
         color: .init(red: 0.545, green: 0.580, blue: 0.620, alpha: 1), width: 540)

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("PNG 인코딩 실패\n".data(using: .utf8)!); exit(1)
}
try! png.write(to: URL(fileURLWithPath: "docs/images/og-image.png"))
FileHandle.standardError.write("생성: docs/images/og-image.png (\(Int(W))×\(Int(H)), \(png.count) bytes)\n".data(using: .utf8)!)
