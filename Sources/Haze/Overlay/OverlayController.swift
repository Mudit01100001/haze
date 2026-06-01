import AppKit
import QuartzCore
import CoreImage
/// application window. Uses CABackdropLayer for zero-CPU native blur.
@MainActor
final class OverlayController {

    private(set) var isActive: Bool = false

    private let overlayWindow: NSWindow
    private let caWindow: NSWindow
    
    private let dimLayer: DimLayer
    private var grainRenderer: GrainRenderer?
    
    private var blurLayer: CALayer?
    private var caLayer: CALayer?
    
    private var currentWindowNumber: CGWindowID?

    init() {
        let screenFrame = ScreenGeometry.mainScreenFrame()

        // --- Window 1: Base Overlay (Blur, Dim, Grain) ---
        overlayWindow = NSWindow(
            contentRect: screenFrame,
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

        let baseContentView = NSView(frame: screenFrame)
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
            contentRect: screenFrame,
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
        
        let caContentView = NSView(frame: screenFrame)
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

    @objc private func settingsDidChange() {
        if isActive {
            refreshLayers()
        }
    }

    func activate(belowWindowNumber windowNumber: CGWindowID) {
        if !isActive {
            isActive = true
            overlayWindow.alphaValue = 0
            caWindow.alphaValue = 0
            
            BootSoundManager.shared.playOnSound(duration: SettingsStore.shared.fadeInDuration)
            
            refreshLayers()
            grainRenderer?.metalView.isPaused = false
            
            let duration = SettingsStore.shared.fadeInDuration
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.overlayWindow.animator().alphaValue = 1.0
                self.caWindow.animator().alphaValue = 1.0
            }
        }
        reorder(belowWindowNumber: windowNumber)
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false

        BootSoundManager.shared.playOffSound(duration: SettingsStore.shared.fadeOutDuration)

        let duration = SettingsStore.shared.fadeOutDuration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.overlayWindow.animator().alphaValue = 0
            self.caWindow.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.isActive {
                    self.overlayWindow.orderOut(nil)
                    self.caWindow.orderOut(nil)
                    self.grainRenderer?.metalView.isPaused = true
                }
            }
        })
    }

    func reorder(belowWindowNumber windowNumber: CGWindowID) {
        guard isActive else { return }
        self.currentWindowNumber = windowNumber
        
        // Set window levels
        if let level = WindowTracker.getWindowLevel(windowID: windowNumber) {
            overlayWindow.level = NSWindow.Level(rawValue: level)
            caWindow.level = NSWindow.Level(rawValue: level)
        }
        
        // Order CA window immediately above the overlay window
        overlayWindow.order(.below, relativeTo: Int(windowNumber))
        caWindow.order(.above, relativeTo: overlayWindow.windowNumber)
        
        applyDynamicVignette(activeWindowID: windowNumber)
    }

    func toggle(belowWindowNumber windowNumber: CGWindowID) {
        if isActive { deactivate() } else { activate(belowWindowNumber: windowNumber) }
    }
    
    func refreshLayers() {
        let store = SettingsStore.shared
        dimLayer.update()
        
        guard let blurLayer = blurLayer, let caLayer = caLayer else { return }
        
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
        
        if let win = currentWindowNumber {
            applyDynamicVignette(activeWindowID: win)
        }
    }
    
    private func applyDynamicVignette(activeWindowID: CGWindowID) {
        let store = SettingsStore.shared
        let screen = ScreenGeometry.mainScreenFrame()
        
        guard let winFrame = WindowTracker.getWindowFrame(windowID: activeWindowID) else { return }
        
        let winX = winFrame.minX - screen.minX
        let winY = screen.height - (winFrame.minY - screen.minY) - winFrame.height
        let activeRect = CGRect(x: winX, y: winY, width: winFrame.width, height: winFrame.height)
        
        // --- 1. Permanent CA Edge Mask ---
        let caMaskLayer = CAGradientLayer()
        caMaskLayer.frame = screen
        caMaskLayer.type = .radial
        caMaskLayer.startPoint = CGPoint(x: 0.5, y: 0.5) // Center of screen
        caMaskLayer.endPoint = CGPoint(x: 1.2, y: 1.2)
        caMaskLayer.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor]
        caMaskLayer.locations = [0.0, 0.6, 1.0] // Smooth transition to opaque edges
        
        // --- 2. Dynamic Blur Alpha Mask (for Dim, Grain, and CA Falloff) ---
        let createDBMask = { () -> CAGradientLayer in
            let mask = CAGradientLayer()
            mask.frame = screen
            mask.type = .radial
            
            let center = CGPoint(
                x: activeRect.midX / screen.width,
                y: activeRect.midY / screen.height
            )
            mask.startPoint = center
            mask.endPoint = CGPoint(x: center.x + 1.2, y: center.y + 1.2)
            
            let clear = NSColor.clear.cgColor
            let black = NSColor.black.cgColor
            
            let windowArea = (activeRect.width * activeRect.height)
            let screenArea = (screen.width * screen.height)
            let baseRatio = max(0.2, min(0.6, sqrt(windowArea / screenArea)))
            let ratio = baseRatio * store.dynamicBlurFalloff
            
            // OPTION A: Frosted Glass Cutout
            // We use a very tight transition (ratio to ratio + 0.015) to create a crisp, sharp edge.
            // This mathematically eliminates the massive ghosting smudge zone.
            if store.invertDynamicBlur {
                mask.colors = [black, clear, clear]
                mask.locations = [0.0, NSNumber(value: min(1.0, ratio)), NSNumber(value: min(1.0, ratio + 0.015))]
            } else {
                mask.colors = [clear, black, black]
                mask.locations = [0.0, NSNumber(value: min(1.0, ratio)), NSNumber(value: min(1.0, ratio + 0.015))]
            }
            return mask
        }
        
        if store.isDynamicRadialBlurEnabled {
            // Unmask sublayers, mask the root overlay window for flat pre-compositing
            dimLayer.mask = nil
            grainRenderer?.metalView.layer?.mask = nil
            
            // Mask the entire root layer to punch a hole in the frosted glass
            overlayWindow.contentView?.layer?.mask = createDBMask()
            
            if store.invertDynamicBlur {
                // DB Inverted: CA drops Edge mask, uses DB mask to fade edges
                caLayer?.mask = nil
                caWindow.contentView?.layer?.mask = createDBMask()
            } else {
                // DB Normal: CA keeps Edge mask AND gets DB mask
                caLayer?.mask = caMaskLayer
                caWindow.contentView?.layer?.mask = createDBMask()
            }
        } else {
            // DB OFF: No DB mask. Dim and Grain are solid. CA gets Edge mask.
            dimLayer.mask = nil
            grainRenderer?.metalView.layer?.mask = nil
            overlayWindow.contentView?.layer?.mask = nil
            caWindow.contentView?.layer?.mask = nil
            caLayer?.mask = caMaskLayer
        }
    }
    
    @objc private func screenParametersDidChange(_ notification: Notification) {
        let newFrame = ScreenGeometry.mainScreenFrame()
        overlayWindow.setFrame(newFrame, display: true)
        caWindow.setFrame(newFrame, display: true)
        
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
