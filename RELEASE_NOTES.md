# Haze Beta 2 Release

## What's New
- **Frosted Glass Cutout Blur**: Completely reimagined the dynamic blur to use a crisp, "frosted glass cutout" transition. This completely eliminates the mathematical alpha-ghosting and smudging of the previous build, leaving a flawlessly sharp window framed by a perfectly clean blur edge.
- **Dual-Window Compositing Architecture**: Split the rendering engine into two perfectly synced hardware-accelerated windows. This allows complex, independent masking of Chromatic Aberration from the Dimming/Grain stack, preventing macOS WindowServer clipping bugs while maintaining a 0% CPU footprint.
- **Dynamic Chromatic Aberration Masking**: CA now intelligently adapts its mask based on your active mode:
    - Normal DB: CA accurately hugs the edges of the frosted glass cutout.
    - Inverted DB: CA cleanly fills the center portal while fading out smoothly at the outer screen edges.
- **Enhanced Acoustic Profile**: Tuned the deactivation sound with an added octave harmonic and amplitude boost for a richer, more satisfying tactile audio response.

---

# Haze Beta 1 Release

## What's New
- **Zero-CPU Architecture**: Completely rebuilt the rendering engine to use native macOS CoreAnimation APIs (`CABackdropLayer`). Haze now runs at a continuous 0% CPU footprint while delivering buttery-smooth realtime blur.
- **Radial Dynamic Blur (Vignette)**: The blur overlay now smoothly falls off around the active application, leaving your center of focus crystal clear and gracefully blurring your peripheral vision.
- **Tactile Soot Grain**: Custom-engineered Film Grain shader uses subtractive blending to render rich, dark texture specs that never wash out contrast or increase display brightness.
- **Intelligent Window Stacking**: Haze now automatically detects the exact internal window level of your active application (even floating panels) and perfectly slips underneath it.
- **Shake to Activate**: Quickly toggle your focus mode by shaking your cursor left and right.

## Known Issues
- Because this is an unsigned developer build, macOS will require you to re-approve Accessibility permissions if you recompile the app from source.
