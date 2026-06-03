import AppKit
import QuartzCore
import CoreImage

@MainActor
private final class ScreenOverlay {
    let screen: NSScreen
    let overlayWindow: NSWindow
    let caWindow: NSWindow
    
    let dimLayer: DimLayer
    var grainRenderer: GrainRenderer?
    
    var blurLayer: CALayer?
    var caLayer: CALayer?
    
    init(screen: NSScreen) {
        self.screen = screen
        let frame = screen.frame
        
        // --- Window 1: Base Overlay (Blur, Dim, Grain) ---
        overlayWindow = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        overlayWindow.level = .normal
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        overlayWindow.hasShadow = false
        overlayWindow.alphaValue = 0

        let baseContentView = NSView(frame: frame)
        baseContentView.wantsLayer = true
        overlayWindow.contentView = baseContentView

        // Layer 1: Blur Backdrop
        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
            let layer = backdropClass.init()
            layer.frame = baseContentView.bounds
            layer.setValue(true, forKey: "windowServerAware")
            blurLayer = layer
            baseContentView.layer?.addSublayer(layer)
        }

        // Layer 2: Dim Layer
        dimLayer = DimLayer()
        dimLayer.frame = baseContentView.bounds
        dimLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        let dimView = NSView(frame: baseContentView.bounds)
        dimView.wantsLayer = true
        dimView.layer?.addSublayer(dimLayer)
        baseContentView.addSubview(dimView)

        // Layer 3: Film Grain
        if let renderer = GrainRenderer(frame: baseContentView.bounds) {
            renderer.metalView.autoresizingMask = [.width, .height]
            baseContentView.addSubview(renderer.metalView)
            grainRenderer = renderer
        }

        // --- Window 2: Chromatic Aberration Overlay ---
        caWindow = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        caWindow.level = .normal
        caWindow.isOpaque = false
        caWindow.backgroundColor = .clear
        caWindow.ignoresMouseEvents = true
        caWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        caWindow.hasShadow = false
        caWindow.alphaValue = 0
        
        let caContentView = NSView(frame: frame)
        caContentView.wantsLayer = true
        caWindow.contentView = caContentView
        
        // Layer 4: CA Backdrop
        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
            let layer = backdropClass.init()
            layer.frame = caContentView.bounds
            layer.setValue(true, forKey: "windowServerAware")
            caLayer = layer
            caContentView.layer?.addSublayer(layer)
        }
    }
    
    func updateFrame() {
        let frame = screen.frame
        overlayWindow.setFrame(frame, display: true)
        caWindow.setFrame(frame, display: true)
        
        if let contentView = overlayWindow.contentView {
            blurLayer?.frame = contentView.bounds
            dimLayer.frame = contentView.bounds
            dimLayer.superlayer?.frame = contentView.bounds
            grainRenderer?.metalView.frame = contentView.bounds
        }
        
        if let caContentView = caWindow.contentView {
            caLayer?.frame = caContentView.bounds
        }
    }
}

/// application window. Uses CABackdropLayer for zero-CPU native blur.
@MainActor
final class OverlayController {

    private(set) var isActive: Bool = false
    
    private var screenOverlays: [CGDirectDisplayID: ScreenOverlay] = [:]
    private var currentWindowNumber: CGWindowID?

    init() {
        setupOverlays()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    private func setupOverlays() {
        let currentDisplays = NSScreen.screens.compactMap { screen -> CGDirectDisplayID? in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
            if screenOverlays[id] == nil {
                screenOverlays[id] = ScreenOverlay(screen: screen)
            }
            return id
        }
        
        // Remove old displays
        for (id, overlay) in screenOverlays {
            if !currentDisplays.contains(id) {
                overlay.overlayWindow.orderOut(nil)
                overlay.caWindow.orderOut(nil)
                screenOverlays.removeValue(forKey: id)
            }
        }
    }

    @objc private func settingsDidChange() {
        if isActive {
            refreshLayers()
        }
    }

    func activate(belowWindowNumber windowNumber: CGWindowID) {
        if !isActive {
            isActive = true
            
            for overlay in screenOverlays.values {
                overlay.overlayWindow.alphaValue = 0
                overlay.caWindow.alphaValue = 0
                overlay.grainRenderer?.metalView.isPaused = false
            }
            
            BootSoundManager.shared.playOnSound(duration: SettingsStore.shared.fadeInDuration)
            
            refreshLayers()
            
            let duration = SettingsStore.shared.fadeInDuration
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                for overlay in self.screenOverlays.values {
                    overlay.overlayWindow.animator().alphaValue = 1.0
                    overlay.caWindow.animator().alphaValue = 1.0
                }
            }
        }
        reorder(belowWindowNumber: windowNumber)
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false

        if SettingsStore.shared.isTurnOffSoundEnabled {
            BootSoundManager.shared.playOffSound(duration: SettingsStore.shared.fadeOutDuration)
        }

        let duration = SettingsStore.shared.fadeOutDuration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for overlay in self.screenOverlays.values {
                overlay.overlayWindow.animator().alphaValue = 0
                overlay.caWindow.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.isActive {
                    for overlay in self.screenOverlays.values {
                        overlay.overlayWindow.orderOut(nil)
                        overlay.caWindow.orderOut(nil)
                        overlay.grainRenderer?.metalView.isPaused = true
                    }
                }
            }
        })
    }

    func reorder(belowWindowNumber windowNumber: CGWindowID) {
        guard isActive else { return }
        self.currentWindowNumber = windowNumber
        
        let level = WindowTracker.getWindowLevel(windowID: windowNumber)
        
        for overlay in screenOverlays.values {
            // Set window levels
            if let level = level {
                overlay.overlayWindow.level = NSWindow.Level(rawValue: level)
                overlay.caWindow.level = NSWindow.Level(rawValue: level)
            }
            
            // Order CA window immediately above the overlay window
            overlay.overlayWindow.order(.below, relativeTo: Int(windowNumber))
            overlay.caWindow.order(.above, relativeTo: overlay.overlayWindow.windowNumber)
        }
        
        applyDynamicVignette(activeWindowID: windowNumber)
    }

    func toggle(belowWindowNumber windowNumber: CGWindowID) {
        if isActive { deactivate() } else { activate(belowWindowNumber: windowNumber) }
    }
    
    func refreshLayers() {
        let store = SettingsStore.shared
        
        for overlay in screenOverlays.values {
            overlay.dimLayer.update()
            
            guard let blurLayer = overlay.blurLayer, let caLayer = overlay.caLayer else { continue }
            
            var blurFilters: [Any] = []
            
            if let caFilterClass = NSClassFromString("CAFilter") as? NSObject.Type {
                if !store.isBlurFreeMode {
                    let blur = caFilterClass.perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur").takeUnretainedValue() as! NSObject
                    let radius = store.isDynamicRadialBlurEnabled ? store.blurRadius * 1.2 : store.blurRadius
                    blur.setValue(radius, forKey: "inputRadius")
                    blur.setValue(true, forKey: "inputHardEdges")
                    blurFilters.append(blur)
                }
                
                if store.isGrayscale {
                    let mono = caFilterClass.perform(NSSelectorFromString("filterWithType:"), with: "colorMonochrome").takeUnretainedValue() as! NSObject
                    mono.setValue(NSColor.white.cgColor, forKey: "inputColor")
                    mono.setValue(store.grayscaleIntensity, forKey: "inputAmount")
                    blurFilters.append(mono)
                }
            }
            
            blurLayer.filters = blurFilters
            
            var caFilters: [Any] = []
            
            if store.isChromaticAberrationEnabled, let caFilterClass = NSClassFromString("CAFilter") as? NSObject.Type {
                let ca = caFilterClass.perform(NSSelectorFromString("filterWithType:"), with: "chromaticAberration").takeUnretainedValue() as! NSObject
                let intensity = store.chromaticAberrationIntensity
                
                ca.setValue(NSValue(point: CGPoint(x: intensity, y: intensity)), forKey: "inputRedOffset")
                ca.setValue(NSValue(point: CGPoint(x: -intensity, y: -intensity)), forKey: "inputBlueOffset")
                ca.setValue(NSValue(point: CGPoint(x: 0, y: 0)), forKey: "inputGreenOffset")
                
                caFilters.append(ca)
            }
            
            caLayer.filters = caFilters
        }
        
        if let win = currentWindowNumber {
            applyDynamicVignette(activeWindowID: win)
        }
    }
    
    private func applyDynamicVignette(activeWindowID: CGWindowID) {
        let store = SettingsStore.shared
        
        guard let rawWinFrame = WindowTracker.getWindowFrame(windowID: activeWindowID) else { return }

        // getWindowFrame returns Quartz global coords (origin = top-left of the PRIMARY display,
        // y-down). NSScreen.frame is Cocoa global coords (origin = bottom-left, y-up). Mixing the
        // two silently broke every secondary display, so convert the window rect into Cocoa global
        // coords once here and work entirely in that space below.
        let winFrame = Self.cocoaGlobalRect(fromQuartz: rawWinFrame)

        // Find which screen contains the center of the active window
        let winCenter = CGPoint(x: winFrame.midX, y: winFrame.midY)
        var activeDisplayID: CGDirectDisplayID? = nil
        
        for (id, overlay) in screenOverlays {
            if overlay.screen.frame.contains(winCenter) {
                activeDisplayID = id
                break
            }
        }
        
        for (id, overlay) in screenOverlays {
            let screen = overlay.screen.frame
            
            // If this is not the active screen, apply a solid mask (or no cutout)
            if id != activeDisplayID {
                // Not the active screen -> Fully blurred.
                // Reset masks so it's a solid sheet of effect. blurLayer must be cleared too, or a
                // stale cutout lingers on this screen after the active window moves to another one.
                overlay.blurLayer?.mask = nil
                overlay.dimLayer.mask = nil
                overlay.grainRenderer?.metalView.layer?.mask = nil
                overlay.overlayWindow.contentView?.layer?.mask = nil
                overlay.caWindow.contentView?.layer?.mask = nil

                let caMaskLayer = CAGradientLayer()
                // A mask's frame is in the masked layer's LOCAL space (origin .zero), not the
                // screen's global origin — using `screen` pushed it off secondary displays.
                caMaskLayer.frame = CGRect(origin: .zero, size: screen.size)
                caMaskLayer.type = .radial
                caMaskLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
                caMaskLayer.endPoint = CGPoint(x: 1.2, y: 1.2)
                caMaskLayer.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor]
                caMaskLayer.locations = [0.0, 0.6, 1.0]
                
                overlay.caLayer?.mask = caMaskLayer
                continue
            }
            
            // THIS IS THE ACTIVE SCREEN
            // winFrame is already Cocoa global; the layer's unit space is bottom-left origin, so
            // the window's local position is just its global position minus this screen's origin.
            let winX = winFrame.minX - screen.minX
            let winY = winFrame.minY - screen.minY
            let activeRect = CGRect(x: winX, y: winY, width: winFrame.width, height: winFrame.height)
            
            // --- 1. Permanent CA Edge Mask ---
            let caMaskLayer = CAGradientLayer()
            caMaskLayer.frame = CGRect(origin: .zero, size: screen.size)
            caMaskLayer.type = .radial
            caMaskLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            caMaskLayer.endPoint = CGPoint(x: 1.2, y: 1.2)
            caMaskLayer.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor]
            caMaskLayer.locations = [0.0, 0.6, 1.0]
            
            // --- 2. Dynamic Blur Alpha Mask (for Dim, Grain, and CA Falloff) ---
            let createDBMask = { () -> CAGradientLayer in
                let mask = CAGradientLayer()
                mask.frame = CGRect(origin: .zero, size: screen.size)
                mask.type = .radial
                
                let center = CGPoint(
                    x: activeRect.midX / screen.width,
                    y: activeRect.midY / screen.height
                )
                mask.startPoint = center
                
                // Determine max distance from center to corners to scale the falloff properly
                let dx = max(center.x, 1.0 - center.x)
                let dy = max(center.y, 1.0 - center.y)
                let maxDist = sqrt(dx*dx + dy*dy)
                
                // CAGradientLayer .radial uses distance from start to end as the X-radius.
                let windowArea = (activeRect.width * activeRect.height)
                let screenArea = (screen.width * screen.height)
                let baseRatio = max(0.1, min(0.6, sqrt(windowArea / screenArea)))
                
                let clear = NSColor.clear.cgColor
                let black = NSColor.black.cgColor
                
                // Scale the physical geometry of the gradient to allow infinite growth without breaking
                var finalRadius = maxDist * baseRatio * store.dynamicBlurFalloff
                
                // If the blur is ONLY in the center, we need to make it larger by default 
                // so it actually spills out from behind the opaque active window!
                if store.invertDynamicBlur {
                    finalRadius *= 2.0 
                }
                
                // FIX: a radial CAGradientLayer derives its radii from (endPoint - startPoint).
                // Offsetting only X left the vertical radius at zero, collapsing the ellipse so the
                // mask rendered as one flat colour and no focal cutout ever formed. Offset Y as well,
                // scaled by the screen aspect ratio so the portal is a true circle on screen.
                // Extend the gradient to 2x the core radius so the smooth falloff ramps in the
                // periphery (beyond the window) instead of fading into the window's own edges.
                let edgeRadius = finalRadius * 2.0
                let aspect = screen.width / screen.height
                mask.endPoint = CGPoint(x: center.x + edgeRadius, y: center.y + edgeRadius * aspect)

                // Smooth depth-of-field falloff: hold the plateau across the inner half (the core,
                // which covers the active window), then ramp gradually over the outer half. Replaces
                // the old 1.5%-wide razor edge that read as a hard circle.
                if store.invertDynamicBlur {
                    mask.colors = [black, black, clear]
                    mask.locations = [0.0, 0.5, 1.0]
                } else {
                    mask.colors = [clear, clear, black]
                    mask.locations = [0.0, 0.5, 1.0]
                }
                return mask
            }
            
            if store.isDynamicRadialBlurEnabled {
                // DO NOT MASK overlayWindow.contentView.layer! This breaks CABackdropLayer in WindowServer!
                // Instead, mask the specific layers that need it (Blur, Dim and Grain)
                overlay.blurLayer?.mask = createDBMask()
                overlay.dimLayer.mask = createDBMask()
                overlay.grainRenderer?.metalView.layer?.mask = createDBMask()
                overlay.overlayWindow.contentView?.layer?.mask = nil
                
                if store.invertDynamicBlur {
                    // CA drops Edge mask, uses DB mask to fade edges
                    overlay.caLayer?.mask = createDBMask()
                    overlay.caWindow.contentView?.layer?.mask = nil
                } else {
                    // CA keeps Edge mask AND gets DB mask (need to combine them)
                    // CoreAnimation doesn't easily support multiple masks on one layer.
                    // But caLayer is a CABackdropLayer, so we CANNOT mask its parent.
                    // We will mask the caLayer with the DB mask, and we'll apply the CA Edge mask to the CA layer's filters or just use DB mask.
                    // Actually, for normal DB, we just use the DB mask for the cutout, and caMaskLayer for the edges.
                    // Since we can't double-mask, let's just use createDBMask() since DB cutout takes priority.
                    overlay.caLayer?.mask = createDBMask()
                    overlay.caWindow.contentView?.layer?.mask = nil
                }
            } else {
                overlay.overlayWindow.contentView?.layer?.mask = nil
                overlay.blurLayer?.mask = nil
                overlay.dimLayer.mask = nil
                overlay.grainRenderer?.metalView.layer?.mask = nil
                overlay.caWindow.contentView?.layer?.mask = nil
                overlay.caLayer?.mask = caMaskLayer
            }
        }
    }
    
    /// Converts a rect from Quartz global coordinates (origin = top-left of the primary display,
    /// y increasing downward — as returned by `CGWindowListCopyWindowInfo`) into Cocoa global
    /// coordinates (origin = bottom-left of the primary display, y increasing upward — the space
    /// `NSScreen.frame` uses). X is identical in both; only Y flips, about the primary's height.
    private static func cocoaGlobalRect(fromQuartz q: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? q.height
        return CGRect(x: q.origin.x,
                      y: primaryHeight - q.origin.y - q.height,
                      width: q.width,
                      height: q.height)
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        setupOverlays()
        for overlay in screenOverlays.values {
            overlay.updateFrame()
        }
        if isActive {
            refreshLayers()
        }
    }
}
