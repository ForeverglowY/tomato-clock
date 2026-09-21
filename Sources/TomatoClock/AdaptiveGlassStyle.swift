import SwiftUI

private struct AdaptiveGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 0.75)
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
        interactive: Bool = false
    ) -> some View {
        modifier(AdaptiveGlassCardModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            interactive: interactive
        ))
    }

    func adaptivePrimaryButton(tint: Color = .red) -> some View {
        modifier(AdaptivePrimaryButtonModifier(tint: tint))
    }
}
