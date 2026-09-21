import SwiftUI

private struct AdaptiveGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool
    let opacity: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(
                .regular
                    .tint((tint ?? .white).opacity(opacity * (tint == nil ? 0.12 : 1)))
                    .interactive(interactive),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(opacity)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.08 + opacity * 0.12), lineWidth: 0.75)
                }
        }
    }
}

private struct AdaptivePrimaryButtonModifier: ViewModifier {
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass(.regular.tint(tint).interactive()))
        } else {
            content.buttonStyle(.borderedProminent).tint(tint)
        }
    }
}

extension View {
    func adaptiveGlassCard(
        cornerRadius: CGFloat = 14,
        tint: Color? = nil,
        interactive: Bool = false,
        opacity: Double = 0.7
    ) -> some View {
        modifier(AdaptiveGlassCardModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            interactive: interactive,
            opacity: min(max(opacity, 0.2), 1)
        ))
    }

    func adaptivePrimaryButton(tint: Color = .red) -> some View {
        modifier(AdaptivePrimaryButtonModifier(tint: tint))
    }
}
