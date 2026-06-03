import SwiftUI

/// Central, singleton settings store for Haze.
/// Every property is backed by `@AppStorage` so it auto-persists to
/// `UserDefaults.standard` and publishes changes to SwiftUI.
final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    // MARK: - Global

    /// Master on/off switch for the overlay.
    @AppStorage("isEnabled") var isEnabled: Bool = true

    // MARK: - Blur

    /// Gaussian blur radius applied to the captured background. Range: 0–40.
    @AppStorage("blurRadius") var blurRadius: Double = 16.0

    /// When true the blur pass is skipped entirely (dim + grain only).
    @AppStorage("isBlurFreeMode") var isBlurFreeMode: Bool = false

    /// Desaturate the captured background to grayscale before compositing.
    @AppStorage("isGrayscale") var isGrayscale: Bool = false

    /// How strongly the grayscale filter is applied. Range: 0–1.
    @AppStorage("grayscaleIntensity") var grayscaleIntensity: Double = 1.0

    /// Whether dynamic radial blur is enabled.
    @AppStorage("isDynamicRadialBlurEnabled") var isDynamicRadialBlurEnabled: Bool = false

    /// Whether dynamic radial blur is inverted (center is blurry instead of clear).
    @AppStorage("invertDynamicBlur") var invertDynamicBlur: Bool = false

    /// Falloff multiplier for the dynamic blur gradient. Default 0.2; menu-bar slider spans 0.1–0.3.
    @AppStorage("dynamicBlurFalloff") var dynamicBlurFalloff: Double = 0.2

    // MARK: - Chromatic Aberration (Lens Effect)

    /// Whether the optical chromatic aberration lens effect is enabled.
    @AppStorage("isChromaticAberrationEnabled") var isChromaticAberrationEnabled: Bool = true

    /// Intensity of the chromatic aberration. Range: 0–20.
    @AppStorage("chromaticAberrationIntensity") var chromaticAberrationIntensity: Double = 5.0

    // MARK: - Bounds Calibration (Additional)
    @AppStorage("minFalloffBoundary") var minFalloffBoundary: Double = 0.1
    @AppStorage("maxFalloffBoundary") var maxFalloffBoundary: Double = 0.3
    
    @AppStorage("minFadeInBoundary") var minFadeInBoundary: Double = 0.0
    @AppStorage("maxFadeInBoundary") var maxFadeInBoundary: Double = 5.0
    
    @AppStorage("minFadeOutBoundary") var minFadeOutBoundary: Double = 0.0
    @AppStorage("maxFadeOutBoundary") var maxFadeOutBoundary: Double = 5.0
    
    @AppStorage("minSensitivityBoundary") var minSensitivityBoundary: Double = 0.1
    @AppStorage("maxSensitivityBoundary") var maxSensitivityBoundary: Double = 20.0
    
    @AppStorage("minCooldownBoundary") var minCooldownBoundary: Double = 0.1
    @AppStorage("maxCooldownBoundary") var maxCooldownBoundary: Double = 5.0

    // MARK: - Audio

    /// Whether the premium bootup synth chime plays on overlay activation.
    @AppStorage("isBootSoundEnabled") var isBootSoundEnabled: Bool = true

    // MARK: - Dim / Overlay

    /// Opacity of the solid-color dim layer. Range: 0–0.9.
    @AppStorage("dimOpacity") var dimOpacity: Double = 0.55

    /// Hex color string (e.g. "#0A0F1E") used for the dim layer.
    @AppStorage("dimColorHex") var dimColorHex: String = "#000000"

    // MARK: - Grain

    /// Intensity / visibility of the grain texture. Range: 0–1.
    @AppStorage("grainIntensity") var grainIntensity: Double = 0.6

    /// Whether the grain texture is animated over time.
    @AppStorage("isGrainAnimated") var isGrainAnimated: Bool = true

    /// Spatial size of individual grain particles, in points. Range: 0.5–4.
    @AppStorage("grainSize") var grainSize: Double = 1.2

    /// Animation speed multiplier for the grain. Range: 0.5–3.
    @AppStorage("grainSpeed") var grainSpeed: Double = 1.5

    // MARK: - Shake Gesture

    /// Multiplier for how easily a shake is detected. Range: 0.5–2.0.
    @AppStorage("shakeSensitivity") var shakeSensitivity: Double = 1.0

    /// Number of direction reversals required to trigger a shake. Range: 2–5.
    @AppStorage("shakeReversals") var shakeReversals: Int = 3

    /// Minimum seconds between successive shake triggers. Range: 0.3–2.5.
    @AppStorage("shakeCooldown") var shakeCooldown: Double = 0.8

    // MARK: - Animation Timing

    /// Duration of the overlay fade-in animation, in seconds. Range: 0.2–2.0.
    @AppStorage("fadeInDuration") var fadeInDuration: Double = 0.6

    /// Duration of the overlay fade-out animation, in seconds. Range: 0.1–1.0.
    @AppStorage("fadeOutDuration") var fadeOutDuration: Double = 0.35

    // MARK: - App Expansion Boundaries

    @AppStorage("minBlurBoundary") var minBlurBoundary: Double = 0.0
    @AppStorage("maxBlurBoundary") var maxBlurBoundary: Double = 40.0

    @AppStorage("minDimmingBoundary") var minDimmingBoundary: Double = 0.0
    @AppStorage("maxDimmingBoundary") var maxDimmingBoundary: Double = 0.9

    @AppStorage("minGrainBoundary") var minGrainBoundary: Double = 0.0
    @AppStorage("maxGrainBoundary") var maxGrainBoundary: Double = 1.0

    @AppStorage("minCABoundary") var minCABoundary: Double = 0.0
    @AppStorage("maxCABoundary") var maxCABoundary: Double = 20.0

    // MARK: - Menu Bar Customization

    @AppStorage("showBlurInMenuBar") var showBlurInMenuBar: Bool = true
    @AppStorage("showDimmingInMenuBar") var showDimmingInMenuBar: Bool = true
    @AppStorage("showGrainInMenuBar") var showGrainInMenuBar: Bool = true
    @AppStorage("showCAInMenuBar") var showCAInMenuBar: Bool = true
    @AppStorage("showGesturesInMenuBar") var showGesturesInMenuBar: Bool = true

    // MARK: - Menu Bar Expansion State (Memory)

    @AppStorage("isBlurExpanded") var isBlurExpanded: Bool = true
    @AppStorage("isDimmingExpanded") var isDimmingExpanded: Bool = true
    @AppStorage("isGrainExpanded") var isGrainExpanded: Bool = true
    @AppStorage("isCAExpanded") var isCAExpanded: Bool = true
    @AppStorage("isGesturesExpanded") var isGesturesExpanded: Bool = true

    // MARK: - Audio Volume

    @AppStorage("isTurnOffSoundEnabled") var isTurnOffSoundEnabled: Bool = true

    @AppStorage("bootSoundVolume") var bootSoundVolume: Double = 1.0
    @AppStorage("turnOffSoundVolume") var turnOffSoundVolume: Double = 1.0

    private init() {}
}
