import SwiftUI

// MARK: - Async content phase (idle → connecting → ready / empty / error / offline)

enum VuumLoadPhase: Equatable {
    case idle
    case connecting
    case ready
    case empty
    case error
    case retrying
    case offline
}

// MARK: - Offline / reconnect banner

struct VuumOfflineBanner: View {
    @EnvironmentObject private var network: NetworkReachability
    var onRetry: (() -> Void)?

    init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }

    var body: some View {
        Group {
            switch network.status {
            case .online:
                EmptyView()
            case .constrained:
                banner(
                    icon: "antenna.radiowaves.left.and.right",
                    title: L10n.t("status.weak_network_title"),
                    detail: L10n.t("status.weak_network_detail"),
                    tint: .orange
                )
            case .offline:
                banner(
                    icon: "wifi.slash",
                    title: L10n.t("status.offline_title"),
                    detail: L10n.t("status.offline_detail"),
                    tint: VuumColor.danger,
                    showsRetry: true
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: network.status)
    }

    private func banner(
        icon: String,
        title: String,
        detail: String,
        tint: Color,
        showsRetry: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.accentOn)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VuumColor.accentOn)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(VuumColor.accentOn.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if showsRetry {
                Button {
                    Task {
                        _ = await network.retry()
                        onRetry?()
                    }
                } label: {
                    Text(L10n.t("status.retry"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(VuumColor.accentOn, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(network.isConnecting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(tint.ignoresSafeArea(edges: .top))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Connecting

struct VuumConnectingView: View {
    var message: String = L10n.t("status.connecting")

    init(message: String = L10n.t("status.connecting")) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(VuumColor.brand)
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(VuumColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - Empty state (with optional action)

struct VuumEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 64, height: 64)
                .background(
                    VuumColor.chipBackground,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(VuumType.callout)
                    .foregroundStyle(VuumColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(VuumType.button)
                        .foregroundStyle(VuumColor.accentOn)
                        .frame(maxWidth: 260)
                        .frame(height: 46)
                        .background(VuumColor.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Recoverable error

struct VuumErrorStateView: View {
    var title: String = L10n.t("status.error_title")
    var message: String = L10n.t("status.error_detail")
    var retryTitle: String = L10n.t("status.try_again")
    var onRetry: () -> Void

    init(
        title: String = L10n.t("status.error_title"),
        message: String = L10n.t("status.error_detail"),
        retryTitle: String = L10n.t("status.try_again"),
        onRetry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 80, height: 80)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(VuumColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onRetry) {
                Text(retryTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VuumColor.accentOn)
                    .frame(maxWidth: 280)
                    .frame(height: 48)
                    .background(VuumColor.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compact inline empty (for List sections)

struct VuumInlineEmptyRow: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
                .symbolRenderingMode(.hierarchical)
                .frame(width: VuumLayout.iconBadge, height: VuumLayout.iconBadge)
                .background(
                    VuumColor.chipBackground,
                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusChip, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(VuumType.bodySemibold)
                    .foregroundStyle(VuumColor.primaryText)
                Text(message)
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hub load wrapper

/// Brief connecting pulse on appear, then content; recoverable error when offline after retry.
struct VuumHubLoadContainer<Content: View>: View {
    @EnvironmentObject private var network: NetworkReachability
    @State private var phase: VuumLoadPhase = .connecting
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            switch phase {
            case .connecting, .retrying:
                VuumConnectingView(
                    message: phase == .retrying
                        ? L10n.t("status.retrying")
                        : L10n.t("status.connecting")
                )
            case .error, .offline:
                VuumErrorStateView(
                    title: network.isReachable
                        ? L10n.t("status.error_title")
                        : L10n.t("status.offline_title"),
                    message: network.isReachable
                        ? L10n.t("status.error_detail")
                        : L10n.t("status.offline_detail")
                ) {
                    Task { await reload(retrying: true) }
                }
            case .idle, .ready, .empty:
                content()
            }
        }
        .task {
            await reload(retrying: false)
        }
    }

    private func reload(retrying: Bool) async {
        phase = retrying ? .retrying : .connecting
        let ok = await network.retry()
        if ok {
            phase = .ready
        } else {
            phase = .offline
        }
    }
}
