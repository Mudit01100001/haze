# Haze Beta Release

## What's New
- **Zero-CPU Architecture**: Completely rebuilt the rendering engine to use native macOS CoreAnimation APIs (`CABackdropLayer`). Haze now runs at a continuous 0% CPU footprint while delivering buttery-smooth realtime blur.
- **Radial Dynamic Blur (Vignette)**: The blur overlay now smoothly falls off around the active application, leaving your center of focus crystal clear and gracefully blurring your peripheral vision.
- **Tactile Soot Grain**: Custom-engineered Film Grain shader uses subtractive blending to render rich, dark texture specs that never wash out contrast or increase display brightness.
- **Intelligent Window Stacking**: Haze now automatically detects the exact internal window level of your active application (even floating panels) and perfectly slips underneath it.
- **Shake to Activate**: Quickly toggle your focus mode by shaking your cursor left and right.

## Known Issues
- Because this is an unsigned developer build, macOS will require you to re-approve Accessibility permissions if you recompile the app from source.
