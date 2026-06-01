# Haze v2.0 Beta Release

## What is New in v2.0
In this massive update, we have completely transformed Haze from a simple static overlay into a dynamic, intelligent focus environment. We introduced complex new optical effects, a completely rebuilt rendering pipeline, and acoustic feedback.

### Dynamic Radial Blur
The flagship feature of v2.0 is the introduction of Dynamic Radial Blur. Instead of a flat, uniform blur across your entire screen, the blur now dynamically reacts to your active window. 
- **How it Works**: It creates a clear "focal portal" around the application you are actively working in, leaving it perfectly sharp, while smoothly increasing the blur radius into your peripheral vision. 
- **The Engineering Journey**: macOS natively forces an alpha blending ghosting smudge when masking blur layers. To achieve a mathematically perfect, smudge-free transition without using heavy Screen Recording permissions, we iterated through Apple's private variable blur filters before ultimately pioneering the **Frosted Glass Cutout**. This technique leverages a razor-sharp, hardware-accelerated mask transition that punches a literal hole through the blur layer, preserving 0% CPU usage while eliminating all ghosting artifacts. 
- **Inverted Mode**: You can also invert the Dynamic Blur, keeping the center heavily blurred (perfect for hiding distracting content) while keeping the edges sharp.

### Chromatic Aberration
We introduced a highly optimized Chromatic Aberration shader to separate the red, green, and blue color channels, simulating the optical imperfections of a real camera lens. 
- **Intelligent Masking**: The Chromatic Aberration intelligently adapts its behavior based on your Dynamic Blur settings. In Normal mode, it hugs the edges of your screen. In Inverted mode, it dynamically shifts to fill the blurry center portal while fading out at the edges.

### Dual Window Compositing Architecture
To support the complex masking required by the new Dynamic Blur and Chromatic Aberration features without triggering macOS WindowServer clipping bugs, we split the Haze rendering engine into two perfectly synchronized, stacked windows. This allows the film grain and dimming layers to composite flatly before being masked, ensuring visual perfection.

### Acoustic Profile
We introduced a subtle acoustic profile for toggling Haze on and off. The deactivation sound has been specifically tuned with a mid-range octave harmonic and an amplitude boost, providing a highly satisfying tactile audio response when exiting your focus session.

---

# Haze v1.0 Beta Release

## Features
- **Zero CPU Architecture**: Completely rebuilt the rendering engine to use native macOS CoreAnimation APIs. Haze runs at a continuous 0% CPU footprint while delivering buttery smooth realtime blur.
- **Tactile Soot Grain**: Custom engineered Film Grain shader uses subtractive blending to render rich, dark texture specs that never wash out contrast or increase display brightness.
- **Intelligent Window Stacking**: Haze automatically detects the exact internal window level of your active application and perfectly slips underneath it.
- **Shake to Activate**: Quickly toggle your focus mode by shaking your cursor left and right.

## Known Issues
- Because this is an unsigned developer build, macOS will require you to reapprove Accessibility permissions if you recompile the app from source.
