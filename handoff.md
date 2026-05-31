# Haze — Developer Handoff & Learnings

This document tracks all the major technical hurdles, errors, and architectural decisions we made while building the **Haze** macOS application. It serves as a knowledge base to prevent running into the same traps in future sessions or projects.

## 1. Zero-CPU Architecture (`CABackdropLayer` vs `ScreenCaptureKit`)
**The Problem:** 
Initially, Haze was built using `ScreenCaptureKit` and a custom Metal `CIGaussianBlur` pipeline. While this allowed maximum flexibility for the blur radius, constantly capturing the screen at 30+ FPS consumed significant CPU/GPU resources (6-15%), defeating the purpose of a lightweight focus app.
**The Solution:**
We discarded `ScreenCaptureKit` entirely and transitioned to Apple's private `CABackdropLayer` CoreAnimation class. `CABackdropLayer` natively hooks into the macOS WindowServer's compositor to blur everything behind it with **0% CPU usage**. Because this is an undocumented class, it cannot be submitted to the Mac App Store, but it is perfect for GitHub-distributed apps.

## 2. Dynamic Blur Vignette (`CAGradientLayer` Masking)
**The Problem:**
We needed the active window to be in focus (clear) while the rest of the screen blurred. A solid `CAShapeLayer` hole-punch resulted in harsh edges.
**The Solution:**
We implemented a massive `CAGradientLayer` of `type = .radial` acting as a mask on the `CABackdropLayer`. The center is completely transparent (`alpha = 0`) and fades into solid black (`alpha = 1`) at the edges. Since mask alpha dictates the visibility of the blur layer, this creates a perfectly smooth depth-of-field "falloff" that gracefully blurs the peripheral vision without requiring a variable blur radius.

## 3. Subtractive "Soot" Film Grain
**The Problem:**
Adding white or colored noise over a blurred background dramatically washed out the contrast and increased the overall brightness of the screen, drawing attention *away* from the active window.
**The Solution:**
The Metal grain shader was rewritten to output **pure black pixels** `(0.0, 0.0, 0.0)` with a randomized `alpha` based on PCG hash noise. Using standard alpha blending (no `compositingFilter`), this creates a rich, subtractive "soot" texture that strictly darkens the image slightly. It adds premium tactile texture without blowing out highlights.

## 4. WindowTracker Race Conditions
**The Problem:**
When switching apps, macOS fires `NSWorkspace.didActivateApplicationNotification`. If we immediately queried `CGWindowListCopyWindowInfo` to find the frontmost window and slide Haze underneath it, Haze would often place itself underneath the *previous* app.
**The Solution:**
The WindowServer takes a fraction of a second to fully update its Z-order list after an activation notification fires. We added a `100ms` asynchronous delay (`Task.sleep(nanoseconds: 100_000_000)`) inside the notification handler. This ensures the Z-order is settled before we determine the frontmost window.

## 5. Floating Windows & Level Matching
**The Problem:**
Haze was sliding behind standard apps, but AI assistants (like Antigravity) or spotlight windows remained stubbornly above the blur overlay.
**The Solution:**
Standard apps operate at `NSWindow.Level.normal` (`kCGWindowLayer = 0`). Floating apps operate at higher layers. We updated `WindowTracker` to parse the specific `kCGWindowLayer` of the newly activated app. `OverlayController` then perfectly matches the overlay's `window.level` to the active app's level before ordering itself below it. This ensures Haze perfectly bisects floating apps from the rest of the screen.

## 6. macOS Security Permissions (The "Ad-Hoc Signature" Bug)
**The Problem:** 
macOS has aggressive security for apps that read the cursor via `CGEventTap`. If you build an app from the terminal or Xcode without a paid Developer Certificate (using "Ad-Hoc" signing), macOS thinks every single build is a brand-new, potentially malicious app. It silently revokes permissions on the next run because the binary hash changed.
**The Solution:**
For local development, you must frequently go to System Settings → Privacy & Security → Accessibility, **delete the old Haze entry with the minus (-) button**, and re-grant it on the next run. For production, the app must be signed with an Apple Developer Certificate so the signature remains stable across updates.
