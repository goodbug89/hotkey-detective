import SwiftUI

struct RadarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0
    static let period: Double = 1.4

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 1).scaleEffect(0.6)
            if !reduceMotion {
                Rectangle()
                    .fill(LinearGradient(colors: [.accentColor.opacity(0.6), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 2)
                    .offset(y: -14)
                    .rotationEffect(.degrees(angle))
            }
            Circle().fill(Color.accentColor).frame(width: 8, height: 8)
        }
        .frame(width: 56, height: 56)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: Self.period).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}
