import SwiftUI

struct CelebrationOverlayView: View {
    let steps: Int
    let distanceKm: Double
    @Binding var isPresented: Bool

    @State private var particles: [ConfettiParticle] = []
    @State private var contentOpacity: Double = 0
    @State private var contentScale: Double = 0.5

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Confetti particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }

            // Content card
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 48))

                Text("축하합니다!")
                    .font(.appBold(size: 24))
                    .foregroundStyle(AppColors.primaryBlueDark)

                Text("오늘의 구간을 완주했어요")
                    .font(.appRegular(size: 14))
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(steps.formatted())")
                            .font(.appBold(size: 28))
                            .foregroundStyle(AppColors.primaryBlueDark)
                        Text("걸음")
                            .font(.appRegular(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.15))
                        .frame(width: 1, height: 40)

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f km", distanceKm))
                            .font(.appBold(size: 28))
                            .foregroundStyle(AppColors.primaryBlueDark)
                        Text("이동 거리")
                            .font(.appRegular(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
        }
        .onAppear {
            spawnConfetti()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                contentOpacity = 1
                contentScale = 1
            }
            // Auto dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            contentOpacity = 0
            contentScale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }

    private func spawnConfetti() {
        let colors: [Color] = [
            AppColors.primaryBlue,
            AppColors.primaryBlueDark,
            AppColors.accentYellow,
            .orange,
            .pink,
            .purple
        ]
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        for i in 0..<40 {
            let startX = CGFloat.random(in: 0...screenWidth)
            let startY = CGFloat.random(in: -50...screenHeight * 0.3)
            let endY = screenHeight + 50
            let size = CGFloat.random(in: 6...14)
            let delay = Double(i) * 0.03

            let particle = ConfettiParticle(
                id: i,
                color: colors.randomElement()!,
                size: size,
                position: CGPoint(x: startX, y: startY),
                opacity: 1
            )
            particles.append(particle)

            let index = particles.count - 1
            let driftX = CGFloat.random(in: -60...60)

            withAnimation(
                .easeIn(duration: Double.random(in: 2.0...3.5))
                .delay(delay)
            ) {
                particles[index].position = CGPoint(
                    x: startX + driftX,
                    y: endY
                )
                particles[index].opacity = 0
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}
