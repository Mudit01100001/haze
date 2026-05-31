import AppKit
import QuartzCore
import CoreImage

/// Manages the full-screen overlay window that sits *below* the frontmost
/// application window. Uses CABackdropLayer for zero-CPU native blur.
@MainActor
final class OverlayController {

    private(set) var isActive: Bool = false

    private let overlayWindow: NSWindow
    private let dimLayer: DimLayer
    private var grainRenderer: GrainRenderer?
    private var backdropLayer: CALayer?
    
    private var currentWindowNumber: CGWindowID?

    init() {
        let screenFrame = ScreenGeometry.mainScreenFrame()

        // --- Window ---
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .normal
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        window.hasShadow = false
        window.alphaValue = 0

        let contentView = NSView(frame: screenFrame)
        contentView.wantsLayer = true
        window.contentView = contentView

        // --- Blur Renderer (CABackdropLayer) ---
        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
            let layer = backdropClass.init()
            layer.frame = contentView.bounds
            layer.setValue(true, forKey: "windowServerAware")
            backdropLayer = layer
            contentView.layer?.addSublayer(layer)
        }

        // --- Dim layer wrapper ---
        // Wrap DimLayer in an NSView so it renders in front of any layer manipulation
        dimLayer = DimLayer()
        dimLayer.frame = contentView.bounds
        dimLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        let dimView = NSView(frame: contentView.bounds)
        dimView.wantsLayer = true
        dimView.layer?.addSublayer(dimLayer)
        contentView.addSubview(dimView)

        // --- Grain Renderer (Metal) ---
        if let renderer = GrainRenderer(frame: contentView.bounds) {
            renderer.metalView.autoresizingMask = [.width, .height]
            contentView.addSubview(renderer.metalView)
            grainRenderer = renderer
        }

        self.overlayWindow = window

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
            
            refreshLayers()
            grainRenderer?.metalView.isPaused = false
            
            let duration = SettingsStore.shared.fadeInDuration
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.overlayWindow.animator().alphaValue = 1.0
            }
        }
        reorder(belowWindowNumber: windowNumber)
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false

        let duration = SettingsStore.shared.fadeOutDuration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.overlayWindow.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.isActive {
                    self.overlayWindow.orderOut(nil)
                    self.grainRenderer?.metalView.isPaused = true
                }
            }
        })
    }

    func reorder(belowWindowNumber windowNumber: CGWindowID) {
        guard isActive else { return }
        self.currentWindowNumber = windowNumber
        
        // Set our window level to match the active window's level exactly
        if let level = WindowTracker.getWindowLevel(windowID: windowNumber) {
            overlayWindow.level = NSWindow.Level(rawValue: level)
        }
        
        overlayWindow.order(.below, relativeTo: Int(windowNumber))
        
        applyDynamicVignette(activeWindowID: windowNumber)
    }

    func toggle(belowWindowNumber windowNumber: CGWindowID) {
        if isActive { deactivate() } else { activate(belowWindowNumber: windowNumber) }
    }

    func refreshLayers() {
        let store = SettingsStore.shared
        dimLayer.update()
        
        guard let backdropLayer = backdropLayer else { return }
        
        // Build private CAFilters
        var filters: [Any] = []
        
        if let caFilterClass = NSClassFromString("CAFilter") as? NSObject.Type {
            if !store.isBlurFreeMode {
                let blur = caFilterClass.perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur").takeUnretainedValue() as! NSObject
                blur.setValue(store.blurRadius, forKey: "inputRadius")
                blur.setValue(true, forKey: "inputHardEdges")
                filters.append(blur)
            }
            
            if store.isGrayscale {
                let mono = caFilterClass.perform(NSSelectorFromString("filterWithType:"), with: "colorMonochrome").takeUnretainedValue() as! NSObject
                mono.setValue(NSColor.gray.cgColor, forKey: "inputColor")
                mono.setValue(store.grayscaleIntensity, forKey: "inputAmount")
                filters.append(mono)
            }
        }
        
        backdropLayer.filters = filters
        
        if let win = currentWindowNumber {
            applyDynamicVignette(activeWindowID: win)
        }
    }
    
    private func applyDynamicVignette(activeWindowID: CGWindowID) {
        let store = SettingsStore.shared
        guard store.isDynamicRadialBlurEnabled, !store.isBlurFreeMode,
              let winFrame = WindowTracker.getWindowFrame(windowID: activeWindowID) else {
            backdropLayer?.mask = nil
            return
        }
        
        // Convert screen coordinates to window coordinates
        let screen = ScreenGeometry.mainScreenFrame()
        let winX = winFrame.minX - screen.minX
        let winY = screen.height - (winFrame.minY - screen.minY) - winFrame.height
        
        let activeRect = CGRect(x: winX, y: winY, width: winFrame.width, height: winFrame.height)
        
        // We use a massive, soft radial gradient mask to simulate "falloff"
        let maskLayer = CAGradientLayer()
        maskLayer.frame = screen
        maskLayer.type = .radial
        
        let center = CGPoint(
            x: activeRect.midX / screen.width,
            y: activeRect.midY / screen.height
        )
        maskLayer.startPoint = center
        
        // Make the gradient extend far enough to cover the screen
        maskLayer.endPoint = CGPoint(x: center.x + 1.2, y: center.y + 1.2)
        
        let clear = NSColor.clear.cgColor
        let black = NSColor.black.cgColor
        
        // We estimate how much of the screen the window takes up to set the start location
        let windowArea = (activeRect.width * activeRect.height)
        let screenArea = (screen.width * screen.height)
        let baseRatio = max(0.2, min(0.6, sqrt(windowArea / screenArea)))
        let ratio = baseRatio * store.dynamicBlurFalloff
        
        if store.invertDynamicBlur {
            // Inverted: center is fully blurred, edges are clear
            maskLayer.colors = [black, clear, clear]
            maskLayer.locations = [0.0, NSNumber(value: min(1.0, ratio)), 1.0]
        } else {
            // Normal: center is fully clear, edges are completely blurred
            maskLayer.colors = [clear, black, black]
            maskLayer.locations = [0.0, NSNumber(value: min(1.0, ratio + 0.3)), 1.0]
        }
        
        backdropLayer?.mask = maskLayer
        
        backdropLayer?.mask = maskLayer
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        let newFrame = ScreenGeometry.mainScreenFrame()
        overlayWindow.setFrame(newFrame, display: true)
        if let contentView = overlayWindow.contentView {
            backdropLayer?.frame = contentView.bounds
            dimLayer.frame = contentView.bounds
            dimLayer.superlayer?.frame = contentView.bounds
            grainRenderer?.metalView.frame = contentView.bounds
        }
    }
}
