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
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.025, green: 0.027, blue: 0.033), Color(red: 0.08, green: 0.0, blue: 0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text("BLACKOUT")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(.white)
                    Text("TASER SIMULATOR")
                        .font(.caption.monospaced().weight(.semibold))
                        .tracking(4)
                        .foregroundStyle(.red.opacity(0.85))
                }
                .padding(.top, 10)

                taserBody
                    .scaleEffect(controller.isFiring && pulse ? 1.025 : 1.0)
                    .animation(.easeInOut(duration: 0.08).repeat(while: controller.isFiring), value: pulse)

                Text(controller.isFiring ? "DISCHARGING" : "READY")
                    .font(.headline.monospaced().weight(.heavy))
                    .tracking(4)
                    .foregroundStyle(controller.isFiring ? .red : .white.opacity(0.72))
                    .padding(.top, 4)

                Text("Tap the red activation button on the taser body to flash the LED and play the sound.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.horizontal, 22)
            }
            .padding(22)
        }
    }

    private var taserBody: some View {
        ZStack {
            // Front cartridge / muzzle housing
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.18, blue: 0.20), Color(red: 0.015, green: 0.015, blue: 0.018)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 252, height: 410)
                .overlay(
                    RoundedRectangle(cornerRadius: 34)
                        .stroke(LinearGradient(colors: [.white.opacity(0.18), .black.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                )
                .shadow(color: .red.opacity(controller.isFiring ? 0.45 : 0.08), radius: controller.isFiring ? 28 : 10)
                .shadow(color: .black.opacity(0.75), radius: 34, y: 24)

            // Grip
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.08, blue: 0.09), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 166, height: 228)
                .offset(y: 100)
                .overlay(
                    VStack(spacing: 10) {
                        ForEach(0..<7) { _ in
                            Capsule()
                                .fill(.white.opacity(0.075))
                                .frame(width: 108, height: 9)
                        }
                    }
                    .offset(y: 100)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                        .offset(y: 100)
                )

            // Top rail
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.92))
                    .frame(width: 178, height: 28)
                    .overlay(
                        HStack(spacing: 12) {
                            ForEach(0..<6) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.13))
                                    .frame(width: 10, height: 18)
                            }
                        }
                    )
                    .padding(.top, 22)
                Spacer()
            }
            .frame(width: 252, height: 410)

            // Probes and status screen
            VStack(spacing: 20) {
                HStack(spacing: 46) {
                    probeCircle
                    probeCircle
                }
                .padding(.top, 64)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.82))
                    .frame(width: 145, height: 64)
                    .overlay(
                        VStack(spacing: 5) {
                            Text(controller.isFiring ? "ACTIVE" : "STANDBY")
                                .font(.caption2.monospaced().weight(.black))
                                .foregroundStyle(controller.isFiring ? .red : .white.opacity(0.65))
                            HStack(spacing: 5) {
                                ForEach(0..<5) { i in
                                    Capsule()
                                        .fill(i < (controller.isFiring ? 5 : 3) ? Color.red : Color.gray.opacity(0.30))
                                        .frame(width: 17, height: 6)
                                }
                            }
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.red.opacity(controller.isFiring ? 0.8 : 0.22), lineWidth: 1))

                Spacer()
            }
            .frame(width: 252, height: 410)

            // Red activation button embedded on the body
            Button {
                controller.fire()
                pulse.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.75))
                        .frame(width: 118, height: 118)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 1.0, green: 0.22, blue: 0.18), Color(red: 0.62, green: 0.0, blue: 0.0), Color(red: 0.20, green: 0.0, blue: 0.0)],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 62
                            )
                        )
                        .frame(width: 94, height: 94)
                        .shadow(color: .red.opacity(controller.isFiring ? 0.95 : 0.45), radius: controller.isFiring ? 26 : 12)
                    Circle()
                        .stroke(.white.opacity(0.32), lineWidth: 2)
                        .frame(width: 94, height: 94)
                    VStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.title2.weight(.black))
                        Text(controller.isFiring ? "ON" : "FIRE")
                            .font(.caption.monospaced().weight(.black))
                    }
                    .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(controller.isFiring)
            .offset(y: 34)

            if controller.isFiring {
                electricArc
                    .offset(y: -92)
            }
        }
    }

    private var probeCircle: some View {
        Circle()
            .fill(LinearGradient(colors: [Color(red: 0.02, green: 0.02, blue: 0.025), Color(red: 0.22, green: 0.22, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 58, height: 58)
            .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 3))
            .overlay(Circle().stroke(.red.opacity(controller.isFiring ? 0.95 : 0.32), lineWidth: 2).blur(radius: controller.isFiring ? 1.5 : 0))
            .overlay(Circle().fill(.red).frame(width: 12, height: 12).blur(radius: controller.isFiring ? 3 : 1))
    }

    private var electricArc: some View {
        ZStack {
            ForEach(0..<4) { i in
                Path { path in
                    path.move(to: CGPoint(x: -42, y: 0))
                    path.addLine(to: CGPoint(x: -20, y: CGFloat([-14, 10, -8, 15][i])))
                    path.addLine(to: CGPoint(x: 0, y: CGFloat([12, -12, 8, -14][i])))
                    path.addLine(to: CGPoint(x: 22, y: CGFloat([-10, 14, -15, 9][i])))
                    path.addLine(to: CGPoint(x: 42, y: 0))
                }
                .stroke(i.isMultiple(of: 2) ? .red : .white, style: StrokeStyle(lineWidth: i.isMultiple(of: 2) ? 5 : 2, lineCap: .round, lineJoin: .round))
                .blur(radius: i.isMultiple(of: 2) ? 1.2 : 0)
                .opacity(pulse ? 1 : 0.45)
            }
        }
        .frame(width: 92, height: 50)
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
