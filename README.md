# Stun Fun

**Stun Fun** is a playful iPhone taser simulator built with SwiftUI. It presents a full-screen, high-voltage-style interface with animated electric arcs, flashlight strobe effects, vibration, and a crackling taser sound.

> For entertainment only. This app is a visual/audio simulator and is not a real safety device.

## TestFlight

Join the public beta:

[https://testflight.apple.com/join/rm43Bct4](https://testflight.apple.com/join/rm43Bct4)

## Privacy

Stun Fun does not collect personal data. See [Privacy Policy](PRIVACY.md).

## Features

- Full-screen black taser-inspired interface
- Animated blue electric arc with flickering plasma glow and branching tendrils
- Large center activation panel
- Camera LED/torch flashing effect on supported iPhones
- Electric crackle sound effect
- Vibration feedback
- iPhone-only portrait layout
- Modern electric app icon

## Screens and Interaction

Tap the large center warning/activation panel to trigger the simulator. While active, Stun Fun:

1. Plays the bundled taser sound
2. Vibrates the device
3. Flashes the camera LED/torch
4. Animates the blue electric arc
5. Lights the red status indicators

The effect automatically stops after a short burst.

## App Details

- App name: **Stun Fun**
- Bundle ID: `com.r0gueee.stunfun`
- Platform: iOS / iPhone
- Minimum iOS version: iOS 16
- UI framework: SwiftUI
- Audio: AVFoundation
- Torch: AVCaptureDevice

## Building Locally

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project.

```bash
brew install xcodegen
xcodegen generate
open StunFun.xcodeproj
```

Then select an iPhone target and run from Xcode.

> The LED/torch effect requires a physical iPhone. It will not work in the iOS Simulator.

## GitHub Actions

The repository includes workflows for:

- Building an unsigned IPA
- Archiving, signing, exporting, and uploading to TestFlight

The TestFlight workflow requires these GitHub Actions secrets:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`

## Project Structure

```text
.github/workflows/        GitHub Actions workflows
TaserSimulator/           SwiftUI app source and assets
TaserSimulator/Resources/ Bundled sound effects
project.yml               XcodeGen project definition
```

## Safety Note

Stun Fun is a novelty simulator. Do not use it to impersonate law enforcement, intimidate others, or create unsafe situations. Flashing lights may affect people with photosensitivity.
