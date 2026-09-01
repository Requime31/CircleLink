import SwiftUI

/// Branded bootstrap screen shown while an authenticated session is restored.
struct LoadingView: View {
    var body: some View {
        ZStack {
            CLColor.canvas.ignoresSafeArea()

            ambientBackground

            VStack(spacing: CLSpacing.lg) {
                ConnectingCircleMark()

                VStack(spacing: CLSpacing.xs) {
                    Text("CircleLink")
                        .font(CLTypography.display)
                        .foregroundStyle(CLColor.primaryPressed)

                    Text("Bringing your circle together…")
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.inkSecondary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CircleLink")
        .accessibilityValue("Loading")
    }

    private var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(CLColor.primary.opacity(0.07))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -120, y: -180)

            Circle()
                .fill(CLColor.inkMuted.opacity(0.05))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 140, y: 280)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ConnectingCircleMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            mark(phase: phase)
        }
        .frame(width: 104, height: 104)
        .background(CLColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        }
        .clFloatingShadow()
        .accessibilityHidden(true)
    }

    private func mark(phase: TimeInterval) -> some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let points = nodePoints(center: center, phase: phase)

            ZStack {
                Path { path in
                    path.move(to: points[0])
                    path.addLine(to: points[1])
                    path.addLine(to: points[2])
                    path.closeSubpath()
                }
                .stroke(CLColor.primary.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                ForEach(points.indices, id: \.self) { index in
                    Circle()
                        .fill(index == 0 ? CLColor.primary : CLColor.primarySoft)
                        .overlay {
                            Circle()
                                .stroke(CLColor.primary.opacity(index == 0 ? 0 : 0.55), lineWidth: 1)
                        }
                        .frame(width: index == 0 ? 20 : 17, height: index == 0 ? 20 : 17)
                        .position(points[index])
                }
            }
        }
    }

    private func nodePoints(center: CGPoint, phase: TimeInterval) -> [CGPoint] {
        let angles = [-Double.pi / 2, Double.pi / 6, Double.pi * 5 / 6]

        return angles.enumerated().map { index, angle in
            // Each node gently moves toward the shared center at a staggered phase.
            let wave = (sin(phase * 2.4 - Double(index) * 0.75) + 1) / 2
            let radius = reduceMotion ? 29 : 25 + wave * 8

            return CGPoint(
                x: center.x + CGFloat(cos(angle) * radius),
                y: center.y + CGFloat(sin(angle) * radius)
            )
        }
    }
}

#Preview("Loading") {
    LoadingView()
}

#Preview("Loading — Dark") {
    LoadingView()
        .preferredColorScheme(.dark)
}
