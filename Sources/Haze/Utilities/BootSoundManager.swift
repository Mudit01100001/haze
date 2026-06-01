import AVFoundation

final class BootSoundManager {
    static let shared = BootSoundManager()
    
    private var engine: AVAudioEngine
    private var sourceNode: AVAudioSourceNode?
    private var reverbNode: AVAudioUnitReverb?
    
    private var isPlaying = false
    private var time: Float = 0
    private let sampleRate: Float = 44100.0
    
    // Warm, analog fundamental
    private let frequency: Float = 150.0 
    
    // Envelope parameters
    private var currentAttackTime: Float = 0.5
    private var currentDecayTime: Float = 1.0
    private var isOffSound: Bool = false
    
    private init() {
        engine = AVAudioEngine()
        setupNode()
    }
    
    private func setupNode() {
        let format = engine.outputNode.inputFormat(forBus: 0)
        let actualSampleRate = Float(format.sampleRate > 0 ? format.sampleRate : Double(sampleRate))
        
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self, self.isPlaying else {
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for frame in 0..<Int(frameCount) {
                    for buffer in ablPointer {
                        let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                        buf[frame] = 0
                    }
                }
                return noErr
            }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            let attack = self.currentAttackTime
            let decay = self.currentDecayTime
            let offSound = self.isOffSound
            
            for frame in 0..<Int(frameCount) {
                let t = self.time
                var envelope: Float = 0.0
                
                if offSound {
                    // For the OFF sound: immediate attack, then decay matching the fade-out
                    if t < decay {
                        let normalizedDecay = t / decay
                        envelope = pow(1.0 - normalizedDecay, 2.0) * 0.4
                    } else {
                        self.isPlaying = false
                        envelope = 0.0
                    }
                } else {
                    // For the ON sound: swell matching the fade-in, then a short tail
                    if t < attack {
                        envelope = 0.5 * (1.0 - cos(.pi * (t / attack)))
                    } else if t < (attack + decay) {
                        let normalizedDecay = (t - attack) / decay
                        envelope = pow(1.0 - normalizedDecay, 2.0)
                    } else {
                        self.isPlaying = false
                        envelope = 0.0
                    }
                }
                
                // Warm fundamental
                let fundamental = sin(2.0 * .pi * self.frequency * t)
                // Perfect 5th harmonic for warmth
                let fifth = sin(2.0 * .pi * (self.frequency * 1.5) * t) * 0.4
                
                var sampleVal = (fundamental + fifth) * envelope * 0.12
                
                if offSound {
                    // Slight pitch bend down for off sound
                    let pitchDrop = max(0.5, 1.0 - (t / decay) * 0.5)
                    let dropFund = sin(2.0 * .pi * (self.frequency * pitchDrop) * t)
                    let dropFifth = sin(2.0 * .pi * (self.frequency * 1.5 * pitchDrop) * t) * 0.4
                    let dropOctave = sin(2.0 * .pi * (self.frequency * 2.0 * pitchDrop) * t) * 0.3
                    
                    // Significantly louder multiplier for off sound with mid-range
                    sampleVal = (dropFund + dropFifth + dropOctave) * envelope * 0.35
                }
                
                self.time += 1.0 / actualSampleRate
                
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = sampleVal
                }
            }
            return noErr
        }
        
        self.sourceNode = sourceNode
        
        // Setup Reverb
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 40.0 // Warm reverb
        self.reverbNode = reverb
        
        engine.attach(sourceNode)
        engine.attach(reverb)
        
        engine.connect(sourceNode, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
        } catch {
            print("BootSoundManager: Failed to start AVAudioEngine - \(error)")
        }
    }
    
    func playOnSound(duration: Double) {
        guard SettingsStore.shared.isBootSoundEnabled else { return }
        time = 0
        currentAttackTime = Float(duration)
        currentDecayTime = 1.0 // 1s tail after full visual fade
        isOffSound = false
        isPlaying = true
        ensureEngineRunning()
    }
    
    func playOffSound(duration: Double) {
        guard SettingsStore.shared.isBootSoundEnabled else { return }
        time = 0
        currentAttackTime = 0.0
        currentDecayTime = Float(duration) // Decay matches the fade out
        isOffSound = true
        isPlaying = true
        ensureEngineRunning()
    }
    
    private func ensureEngineRunning() {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("BootSoundManager: Failed to start AVAudioEngine - \(error)")
            }
        }
    }
}
