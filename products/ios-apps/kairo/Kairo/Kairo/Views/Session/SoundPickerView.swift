import SwiftUI

/// A sheet presenting ambient sound options in a 2-column grid.
///
/// Features:
/// - Tap to select a sound
/// - Long-press or secondary tap to preview (3-second sample)
/// - Volume slider
/// - Shown as `.sheet` from FocusSessionView before starting a session
struct SoundPickerView: View {

    @ObservedObject private var soundManager = SoundManager.shared
    @Environment(\.dismiss) private var dismiss

    /// Callback when user confirms selection.
    var onConfirm: ((SoundType) -> Void)?

    // MARK: - State

    @State private var previewingSound: SoundType?
    @State private var previewTimer: Timer?

    // MARK: - Grid

    private let columns = [
        GridItem(.flexible(), spacing: KairoTheme.Spacing.sm),
        GridItem(.flexible(), spacing: KairoTheme.Spacing.sm)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                KairoColors.backgroundAdaptive
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: KairoTheme.Spacing.lg) {
                        headerSection
                        soundGrid
                        volumeSection
                        confirmButton
                    }
                    .padding(.horizontal, KairoTheme.Spacing.md)
                    .padding(.vertical, KairoTheme.Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(KairoTypography.label)
                    .foregroundColor(KairoColors.accentAdaptive)
                }
            }
        }
        .onDisappear {
            cancelPreview()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: KairoTheme.Spacing.xs) {
            Image(systemName: "headphones")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(KairoColors.accentAdaptive)

            Text("Ambient Sound")
                .font(KairoTypography.heading2)
                .foregroundColor(KairoColors.primaryAdaptive)

            Text("Choose a soundscape for your focus session")
                .font(KairoTypography.body)
                .foregroundColor(KairoColors.mutedAdaptive)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, KairoTheme.Spacing.xs)
    }

    // MARK: - Sound Grid

    private var soundGrid: some View {
        LazyVGrid(columns: columns, spacing: KairoTheme.Spacing.sm) {
            ForEach(SoundType.allCases) { sound in
                SoundOptionCell(
                    sound: sound,
                    isSelected: soundManager.selectedSound == sound,
                    isPreviewing: previewingSound == sound,
                    onTap: { selectSound(sound) },
                    onPreview: { previewSound(sound) }
                )
            }
        }
    }

    // MARK: - Volume Section

    private var volumeSection: some View {
        VStack(spacing: KairoTheme.Spacing.xs) {
            HStack {
                Text("Volume")
                    .font(KairoTypography.label)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Spacer()

                Text("\(Int(soundManager.volume * 100))%")
                    .font(KairoTypography.scoreSmall)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            HStack(spacing: KairoTheme.Spacing.sm) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 12))
                    .foregroundColor(KairoColors.mutedAdaptive)

                Slider(
                    value: $soundManager.volume,
                    in: 0.0...1.0,
                    step: 0.05
                )
                .tint(soundManager.selectedSound.color)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
        }
        .padding(KairoTheme.Spacing.md)
        .background(KairoColors.surfaceAdaptive)
        .cornerRadius(KairoTheme.Radius.medium)
        .opacity(soundManager.selectedSound == .silence ? 0.4 : 1.0)
        .disabled(soundManager.selectedSound == .silence)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button(action: {
            onConfirm?(soundManager.selectedSound)
            dismiss()
        }) {
            HStack(spacing: KairoTheme.Spacing.xs) {
                Image(systemName: soundManager.selectedSound == .silence
                      ? "speaker.slash.fill"
                      : "play.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text(soundManager.selectedSound == .silence
                     ? "Continue Without Sound"
                     : "Start with \(soundManager.selectedSound.displayName)")
                    .font(KairoTypography.heading3)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                    .fill(soundManager.selectedSound.color)
            )
            .shadow(
                color: KairoTheme.Shadow.button.color,
                radius: KairoTheme.Shadow.button.radius,
                y: KairoTheme.Shadow.button.y
            )
        }
        .padding(.top, KairoTheme.Spacing.xs)
    }

    // MARK: - Actions

    private func selectSound(_ sound: SoundType) {
        cancelPreview()
        withAnimation(KairoTheme.Animation.quick) {
            soundManager.select(sound)
        }
    }

    private func previewSound(_ sound: SoundType) {
        cancelPreview()
        guard sound != .silence else { return }

        previewingSound = sound
        soundManager.preview(sound, duration: 3.0)

        // Clear preview indicator after 3 seconds
        previewTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [self] _ in
            DispatchQueue.main.async {
                withAnimation(KairoTheme.Animation.quick) {
                    self.previewingSound = nil
                }
            }
        }
    }

    private func cancelPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        previewingSound = nil
    }
}

// MARK: - Sound Option Cell

private struct SoundOptionCell: View {

    let sound: SoundType
    let isSelected: Bool
    let isPreviewing: Bool
    let onTap: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: KairoTheme.Spacing.sm) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? sound.color.opacity(0.2)
                              : KairoColors.mutedAdaptive.opacity(0.08))
                        .frame(width: 56, height: 56)

                    Image(systemName: sound.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? sound.color : KairoColors.mutedAdaptive)

                    // Previewing pulse
                    if isPreviewing {
                        Circle()
                            .stroke(sound.color, lineWidth: 2)
                            .frame(width: 56, height: 56)
                            .scaleEffect(isPreviewing ? 1.3 : 1.0)
                            .opacity(isPreviewing ? 0.0 : 1.0)
                            .animation(
                                .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                value: isPreviewing
                            )
                    }
                }

                // Name
                Text(sound.displayName)
                    .font(KairoTypography.label)
                    .foregroundColor(isSelected
                                     ? KairoColors.primaryAdaptive
                                     : KairoColors.mutedAdaptive)

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(sound.color)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Preview hint
                    Text("Hold to preview")
                        .font(KairoTypography.caption)
                        .foregroundColor(KairoColors.mutedAdaptive.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: KairoTheme.Radius.card)
                    .fill(isSelected
                          ? sound.color.opacity(0.06)
                          : KairoColors.surfaceAdaptive)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairoTheme.Radius.card)
                    .stroke(
                        isSelected ? sound.color.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onPreview()
                }
        )
        .animation(KairoTheme.Animation.quick, value: isSelected)
    }
}

// MARK: - Preview

#Preview("Sound Picker") {
    SoundPickerView()
}
