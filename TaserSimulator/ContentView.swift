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
            RadialGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.22), .black], center: .top, startRadius: 80, endRadius: 720)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("TASER")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .tracking(7)
                        .foregroundStyle(.yellow)
                    Text("SIMULATOR")
                        .font(.headline.monospaced())
                        .tracking(5)
                        .foregroundStyle(.white.opacity(0.75))
                }

                taserBody
                    .scaleEffect(controller.isFiring && pulse ? 1.025 : 1.0)
                    .animation(.easeInOut(duration: 0.08).repeat(while: controller.isFiring), value: pulse)

                Button {
                    controller.fire()
                    pulse.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: controller.isFiring ? "bolt.fill" : "bolt.circle.fill")
                        Text(controller.isFiring ? "FIRING" : "PRESS TO FIRE")
                    }
                    .font(.title2.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .foregroundStyle(.black)
                    .background(controller.isFiring ? Color.yellow : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .yellow.opacity(controller.isFiring ? 0.85 : 0.35), radius: controller.isFiring ? 28 : 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.45), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(controller.isFiring)

                Text("Flashes the camera LED and plays an electric crackle sound. For entertainment only.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal)
            }
            .padding(24)
        }
    }

    private var taserBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.78, blue: 0.12), Color(red: 0.68, green: 0.43, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 250, height: 430)
                .shadow(color: .black.opacity(0.55), radius: 30, y: 22)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black.opacity(0.82))
                .frame(width: 172, height: 250)
                .offset(y: 72)

            VStack(spacing: 22) {
                HStack(spacing: 50) {
                    probeCircle
                    probeCircle
                }
                .padding(.top, 34)

                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.7))
                    .frame(width: 138, height: 58)
                    .overlay(
                        VStack(spacing: 4) {
                            Text(controller.isFiring ? "ARMED" : "SAFE")
                                .font(.caption2.monospaced().weight(.bold))
                                .foregroundStyle(controller.isFiring ? .red : .green)
                            HStack(spacing: 4) {
                                ForEach(0..<5) { i in
                                    Capsule()
                                        .fill(i < (controller.isFiring ? 5 : 3) ? Color.green : Color.gray.opacity(0.35))
                                        .frame(width: 16, height: 6)
                                }
                            }
                        }
                    )

                Spacer()
            }
            .frame(width: 250, height: 430)

            if controller.isFiring {
                electricArc
                    .offset(y: -144)
            }
        }
    }

    private var probeCircle: some View {
        Circle()
            .fill(.black)
            .frame(width: 54, height: 54)
            .overlay(Circle().stroke(.yellow.opacity(0.8), lineWidth: 4))
            .overlay(Circle().fill(.cyan).frame(width: 14, height: 14).blur(radius: 2))
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
                .stroke(i.isMultiple(of: 2) ? .cyan : .white, style: StrokeStyle(lineWidth: i.isMultiple(of: 2) ? 5 : 2, lineCap: .round, lineJoin: .round))
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
