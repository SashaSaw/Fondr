import SwiftUI

struct FondrButton: View {
    let title: String
    let variant: Variant
    let action: () -> Void

    enum Variant {
        case filled
        case outlined
    }

    init(_ title: String, variant: Variant = .filled, action: @escaping () -> Void) {
        self.title = title
        self.variant = variant
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(backgroundStyle)
                .foregroundStyle(foregroundStyle)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if variant == .outlined {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.fondrPrimary, lineWidth: 2)
                    }
                }
        }
    }

    @ViewBuilder
    private var backgroundStyle: some View {
        switch variant {
        case .filled:
            Color.fondrPrimary
        case .outlined:
            Color.clear
        }
    }

    private var foregroundStyle: Color {
        switch variant {
        case .filled:
            .white
        case .outlined:
            .fondrPrimary
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FondrButton("Get Started") {}
        FondrButton("Learn More", variant: .outlined) {}
    }
    .padding()
}
