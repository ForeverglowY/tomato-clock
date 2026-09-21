import SwiftUI

struct FocusGoalRing: View {
    let progress: Double
    var size: CGFloat = 58
    var lineWidth: CGFloat = 7
    var showsCenterIcon = true

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.orange.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: [.orange, .red, .pink, .orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: .orange.opacity(clampedProgress >= 1 ? 0.45 : 0), radius: 5)
            if showsCenterIcon {
                Image(systemName: clampedProgress >= 1 ? "checkmark" : "flame.fill")
                    .font(.system(size: size * 0.27, weight: .bold))
                    .foregroundStyle(clampedProgress >= 1 ? Color.green : Color.orange)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.35), value: clampedProgress)
        .accessibilityLabel("每日专注目标")
        .accessibilityValue("完成 \(Int((clampedProgress * 100).rounded()))%")
    }
}
