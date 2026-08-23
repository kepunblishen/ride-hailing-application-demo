import SwiftUI

struct VuumPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var showArrow: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(VuumColor.brandInk)
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                        if showArrow {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(VuumColor.brandInk)
            .background(VuumColor.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

/// Capsule CTA matching the Wells design-system button shape (Vuum colors).
struct VuumPrimaryCapsuleButton: View {
    let title: String
    var isLoading: Bool = false
    var showArrow: Bool = false
    let action: () -> Void

    private var fillColor: Color {
        isLoading ? VuumColor.brand.opacity(0.85) : VuumColor.brand
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: VuumColor.brandInk))
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                        if showArrow {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(VuumColor.brandInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(fillColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct VuumSheetChrome<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(VuumColor.divider)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            if let title {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .VuumGlassSurface(cornerRadius: 24)
        .shadow(color: .black.opacity(0.12), radius: 16, y: -2)
    }
}
