import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit

final class TaserController: ObservableObject {
    @Published var isFiring = false

    private var audioPlayer: AVAudioPlayer?
    private var flashTask: Task<Void, Never>?

    init() {
        prepareAudio()
    }

    func fire() {
        guard !isFiring else { return }
        isFiring = true
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
        startFlashing()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            stop()
        }
    }

    func stop() {
        isFiring = false
        audioPlayer?.stop()
        flashTask?.cancel()
        flashTask = nil
        setTorch(on: false)
    }

    private func prepareAudio() {
        guard let url = Bundle.main.url(forResource: "taser", withExtension: "wav") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.prepareToPlay()
        } catch {
            print("Audio setup failed: \(error)")
        }
    }

    private func startFlashing() {
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            var on = false
            while !Task.isCancelled {
                on.toggle()
                await self?.setTorchAsync(on: on)
                try? await Task.sleep(nanoseconds: 85_000_000)
            }
            await self?.setTorchAsync(on: false)
        }
    }

    @MainActor
    private func setTorchAsync(on: Bool) {
        setTorch(on: on)
    }

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: min(AVCaptureDevice.maxAvailableTorchLevel, 0.9))
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch failed: \(error)")
        }
    }
}

struct ContentView: View {
    @StateObject private var controller = TaserController()
    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.black.ignoresSafeArea()

                RadialGradient(
                    colors: [Color.blue.opacity(controller.isFiring ? 0.28 : 0.12), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: size.height * 0.65
                )
                .ignoresSafeArea()

                taserShell(size: size)
                    .frame(width: size.width, height: size.height)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func taserShell(size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let bodyW = min(w * 0.86, 390)
        let topY = h * 0.11
        let centerX = w / 2

        return ZStack {
            // Full-screen taser silhouette
            TaserSilhouette()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.18, blue: 0.19), Color(red: 0.035, green: 0.035, blue: 0.04), Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: bodyW, height: h * 0.92)
                .position(x: centerX, y: h * 0.58)
                .shadow(color: .black, radius: 35, y: 18)
                .overlay(
                    TaserSilhouette()
                        .stroke(LinearGradient(colors: [.white.opacity(0.22), .black.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                        .frame(width: bodyW, height: h * 0.92)
                        .position(x: centerX, y: h * 0.58)
                )

            // Armor panels
            VStack(spacing: h * 0.016) {
                Spacer().frame(height: h * 0.24)

                warningPlate
                    .frame(width: bodyW * 0.62, height: h * 0.22)

                statusLights
                    .frame(width: bodyW * 0.24, height: 34)
                    .padding(.top, h * 0.01)

                activationSwitch
                    .frame(width: bodyW * 0.30, height: h * 0.17)
                    .padding(.top, h * 0.035)

                Spacer()
            }
            .position(x: centerX, y: h * 0.56)

            sideArmor(width: bodyW, height: h)
                .position(x: centerX, y: h * 0.55)

            topProngs(bodyW: bodyW, topY: topY, centerX: centerX)

            if controller.isFiring {
                electricArc(width: bodyW * 0.70)
                    .frame(width: bodyW * 0.72, height: 92)
                    .position(x: centerX, y: topY + 40)
                    .transition(.opacity)
            } else {
                electricArc(width: bodyW * 0.70)
                    .frame(width: bodyW * 0.72, height: 92)
                    .position(x: centerX, y: topY + 40)
                    .opacity(0.42)
            }

            Button {
                controller.fire()
                pulse.toggle()
            } label: {
                Color.clear
            }
            .buttonStyle(.plain)
            .disabled(controller.isFiring)
            .frame(width: bodyW * 0.45, height: h * 0.23)
            .position(x: centerX, y: h * 0.71)
            .accessibilityLabel("Fire Stun Fun")
        }
    }

    private var warningPlate: some View {
        ZStack {
            CutCornerPanel(cut: 26)
                .fill(LinearGradient(colors: [Color(red: 0.11, green: 0.11, blue: 0.12), Color(red: 0.025, green: 0.025, blue: 0.03)], startPoint: .top, endPoint: .bottom))
                .overlay(CutCornerPanel(cut: 26).stroke(.white.opacity(0.14), lineWidth: 2))
                .shadow(color: .black.opacity(0.8), radius: 12, y: 7)

            VStack(spacing: 7) {
                ZStack {
                    Triangle()
                        .fill(Color.yellow.opacity(0.96))
                        .frame(width: 74, height: 64)
                    Triangle()
                        .stroke(.black.opacity(0.88), lineWidth: 5)
                        .frame(width: 74, height: 64)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(.black)
                        .offset(y: 7)
                }

                Text("STUN FUN")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("HIGH VOLTAGE")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(.yellow.opacity(0.82))
            }
            .padding(.vertical, 10)
        }
    }

    private var statusLights: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black.opacity(0.74))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(.red.opacity(0.55), lineWidth: 2)
            )
            .overlay(
                HStack(spacing: 8) {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .shadow(color: .red, radius: controller.isFiring ? 13 : 6)
                    }
                }
            )
    }

    private var activationSwitch: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.yellow)
                .shadow(color: .yellow.opacity(0.55), radius: 12)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
                .padding(8)
            VStack(spacing: 7) {
                ForEach(0..<5) { _ in
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.24), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 52, height: 9)
                }
            }
            .offset(y: controller.isFiring ? -8 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.65), value: controller.isFiring)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.20), lineWidth: 1)
        )
    }

    private func sideArmor(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                SideRail(side: side)
                    .fill(LinearGradient(colors: [Color(red: 0.18, green: 0.18, blue: 0.19), .black], startPoint: .top, endPoint: .bottom))
                    .frame(width: width * 0.22, height: height * 0.42)
                    .offset(x: side * width * 0.40, y: -height * 0.12)
                    .overlay(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                            .offset(x: side * width * 0.40, y: -height * 0.25)
                    )
            }
        }
    }

    private func topProngs(bodyW: CGFloat, topY: CGFloat, centerX: CGFloat) -> some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                VStack(spacing: -2) {
                    Triangle()
                        .fill(LinearGradient(colors: [.white, Color(red: 0.55, green: 0.56, blue: 0.62), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 30, height: 74)
                        .shadow(color: .blue.opacity(controller.isFiring ? 0.9 : 0.35), radius: controller.isFiring ? 16 : 7)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
                        .frame(width: 58, height: 92)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.18), lineWidth: 1))
                }
                .position(x: centerX + side * bodyW * 0.36, y: topY + 55)
            }
        }
    }

    private func electricArc(width: CGFloat) -> some View {
        ZStack {
            ForEach(0..<5) { i in
                ElectricBolt(seed: i)
                    .stroke(i == 0 ? .white : Color(red: 0.25, green: 0.42, blue: 1.0), style: StrokeStyle(lineWidth: i == 0 ? 3 : 7, lineCap: .round, lineJoin: .round))
                    .blur(radius: i == 0 ? 0 : CGFloat(i) * 0.7)
                    .opacity(controller.isFiring ? (pulse ? 1.0 : 0.62) : 0.50)
                    .shadow(color: .blue, radius: controller.isFiring ? 12 : 6)
            }
        }
        .onChange(of: controller.isFiring) { active in
            if active { pulse.toggle() }
        }
        .animation(.easeInOut(duration: 0.075).repeat(while: controller.isFiring), value: pulse)
    }
}

struct TaserSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.25, y: 0))
        p.addLine(to: CGPoint(x: w * 0.75, y: 0))
        p.addLine(to: CGPoint(x: w * 0.93, y: h * 0.16))
        p.addLine(to: CGPoint(x: w * 0.93, y: h * 0.43))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.54))
        p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.68, y: h))
        p.addLine(to: CGPoint(x: w * 0.32, y: h))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.54))
        p.addLine(to: CGPoint(x: w * 0.07, y: h * 0.43))
        p.addLine(to: CGPoint(x: w * 0.07, y: h * 0.16))
        p.closeSubpath()
        return p
    }
}

struct SideRail: Shape {
    let side: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        if side < 0 {
            p.move(to: CGPoint(x: w, y: 0))
            p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.04))
            p.addLine(to: CGPoint(x: 0, y: h * 0.22))
            p.addLine(to: CGPoint(x: 0, y: h * 0.94))
            p.addLine(to: CGPoint(x: w * 0.65, y: h))
            p.addLine(to: CGPoint(x: w, y: h * 0.77))
        } else {
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.04))
            p.addLine(to: CGPoint(x: w, y: h * 0.22))
            p.addLine(to: CGPoint(x: w, y: h * 0.94))
            p.addLine(to: CGPoint(x: w * 0.35, y: h))
            p.addLine(to: CGPoint(x: 0, y: h * 0.77))
        }
        p.closeSubpath()
        return p
    }
}

struct CutCornerPanel: Shape {
    let cut: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        p.closeSubpath()
        return p
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct ElectricBolt: Shape {
    let seed: Int
    func path(in rect: CGRect) -> Path {
        let variants: [[CGFloat]] = [
            [0.45, 0.22, 0.66, 0.30, 0.58, 0.70, 0.38],
            [0.57, 0.35, 0.50, 0.25, 0.72, 0.42, 0.55],
            [0.50, 0.72, 0.32, 0.63, 0.40, 0.26, 0.48],
            [0.42, 0.55, 0.24, 0.45, 0.62, 0.36, 0.50],
            [0.64, 0.45, 0.74, 0.28, 0.49, 0.58, 0.46]
        ]
        let ys = variants[seed % variants.count]
        var p = Path()
        let count = ys.count
        p.move(to: CGPoint(x: rect.minX + 4, y: rect.midY))
        for i in 0..<count {
            let x = rect.minX + CGFloat(i + 1) * (rect.width - 8) / CGFloat(count + 1)
            let y = rect.minY + ys[i] * rect.height
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.midY))
        return p
    }
}

private extension Animation {
    func `repeat`(while condition: Bool) -> Animation {
        condition ? self.repeatForever(autoreverses: true) : self
    }
}

#Preview {
    ContentView()
}
