# Haze v2.0.1 — Dynamic Blur Fixes

A bug-fix release focused on Dynamic Radial Blur reliability and feel.

### Multi-Monitor Support
Fixed Dynamic Radial Blur on multi-display setups. The active window's position was being computed by mixing two different coordinate systems (Quartz window bounds vs. Cocoa screen frames), which collapsed the focal portal on any secondary display — the active monitor would show nothing while the inactive one blurred fully. Window coordinates are now converted into a single consistent space using the primary display's geometry, so the clear portal lands correctly on the active window on every screen. Moving focus between monitors now hands the portal off cleanly, and a stray mask offset that misplaced the Chromatic Aberration layer on secondary displays was fixed too.

### Smooth Falloff
Replaced the hard-edged focal circle with a true, smooth depth-of-field transition. The gradient now extends past the active window and ramps gradually from clear into the blurred periphery, instead of cutting off at a sharp line — without fading into the window's own edges.

### Falloff Slider
Recentered the menu-bar Blur Falloff slider so its default sits in the middle of the range, and fixed a mismatch between the reset marker and the actual default value.

---

# Haze v2.0 Beta Release

## What is New in v2.0
Transformed Haze from a static overlay into a dynamic focus environment. Introduced new optical effects, rebuilt the rendering pipeline, and added audio signaling.

### Dynamic Radial Blur
Introduced Dynamic Radial Blur. Instead of a flat, uniform blur across the screen, the blur overlay now reacts to the active window. 
- **How it Works**: Creates a clear focal portal around the active application, leaving it sharp, while increasing the blur radius into the peripheral vision. 
- **The Engineering Journey**: macOS natively forces an alpha blending ghosting effect when masking standard blur layers. To achieve a clean transition without using Screen Recording permissions, the implementation uses a frosted glass cutout approach. This technique applies a sharp mask transition that cuts a defined hole through the blur layer, preserving 0% CPU usage while eliminating ghosting artifacts. 
- **Inverted Mode**: Supports inverting the Dynamic Blur, keeping the center heavily blurred (to hide distracting content) while keeping the edges sharp.

### Chromatic Aberration
Added a Chromatic Aberration shader to separate the red, green, and blue color channels, simulating the optical imperfections of a physical camera lens. 
- **Intelligent Masking**: Adapts its behavior based on the Dynamic Blur settings. In Normal mode, it masks to the edges of the screen. In Inverted mode, it shifts to fill the blurry center portal while fading out at the edges.

### Dual Window Compositing Architecture
Split the Haze rendering engine into two synchronized, stacked windows to support complex masking for Dynamic Blur and Chromatic Aberration. This isolates the layers and prevents macOS WindowServer clipping bugs, allowing the film grain and dimming layers to composite flatly before being masked.

### Animated Film Grain
Upgraded the film grain from a static texture to a dynamically animated shader. The grain now continuously shifts and updates in real-time, providing a more authentic and tactile visual noise profile.

### Audio Signaling
Implemented auditory feedback for toggling Haze on and off. Utilizes programmatically generated sine wave oscillators rather than static audio files. The deactivation sound incorporates a mid-range octave harmonic and an amplitude boost to provide a distinct audio signal when exiting a focus session.

---

# Haze v1.0 Beta Release

## Features
- **Zero CPU Architecture**: Rebuilt the rendering engine to use native macOS CoreAnimation APIs. Runs at a continuous 0% CPU footprint while delivering realtime blur.
- **Tactile Soot Grain**: Custom Film Grain shader uses subtractive blending to render dark texture specs that do not wash out contrast or increase display brightness.
- **Intelligent Window Stacking**: Automatically detects the exact internal window level of the active application and slips underneath it.
- **Shake to Activate**: Toggle focus mode by shaking the cursor left and right.

## Known Issues
- Because this is an unsigned developer build, macOS will require reapproving Accessibility permissions if recompiled from source.
