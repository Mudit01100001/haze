import SwiftUI

struct EffectsConfigView: View {
    @ObservedObject var settings = SettingsStore.shared
    
    // Help popover states
    @State private var showingBlurHelp = false
    @State private var showingDimHelp = false
    @State private var showingGrainHelp = false
    @State private var showingCAHelp = false
    @State private var showingGesturesHelp = false
    
    var body: some View {
        Form {
            Section {
                boundarySliders(
                    title: "Blur Boundaries",
                    minVal: $settings.minBlurBoundary, maxVal: $settings.maxBlurBoundary,
                    minAbsoluteRange: -100...100, maxAbsoluteRange: 0...200,
                    helpState: $showingBlurHelp, helpText: "Defines the absolute minimum and maximum blur radius. Moving the slider in the menu bar will interpolate between these two bounds."
                )
                
                boundarySliders(
                    title: "Dynamic Radial Falloff",
                    minVal: $settings.minFalloffBoundary, maxVal: $settings.maxFalloffBoundary,
                    minAbsoluteRange: -20.0...20.0, maxAbsoluteRange: 0.1...50.0,
                    helpState: .constant(false), helpText: ""
                )
            } header: {
                Text("BLUR")
            }
            
            Section {
                boundarySliders(
                    title: "Dimming Boundaries",
                    minVal: $settings.minDimmingBoundary, maxVal: $settings.maxDimmingBoundary,
                    minAbsoluteRange: -1.0...1.0, maxAbsoluteRange: 0.0...2.0,
                    helpState: $showingDimHelp, helpText: "Sets the maximum darkness allowed."
                )
                
                boundarySliders(
                    title: "Fade In Boundaries (Seconds)",
                    minVal: $settings.minFadeInBoundary, maxVal: $settings.maxFadeInBoundary,
                    minAbsoluteRange: -5.0...10.0, maxAbsoluteRange: 0.0...20.0,
                    helpState: .constant(false), helpText: ""
                )
                
                boundarySliders(
                    title: "Fade Out Boundaries (Seconds)",
                    minVal: $settings.minFadeOutBoundary, maxVal: $settings.maxFadeOutBoundary,
                    minAbsoluteRange: -5.0...10.0, maxAbsoluteRange: 0.0...20.0,
                    helpState: .constant(false), helpText: ""
                )
            } header: {
                Text("OVERLAY / DIMMING")
            }
            
            Section {
                boundarySliders(
                    title: "Film Grain Boundaries",
                    minVal: $settings.minGrainBoundary, maxVal: $settings.maxGrainBoundary,
                    minAbsoluteRange: -5.0...5.0, maxAbsoluteRange: 0.0...20.0,
                    helpState: $showingGrainHelp, helpText: "Controls the subtractive 'soot' texture boundaries."
                )
            } header: {
                Text("FILM GRAIN")
            }
            
            Section {
                boundarySliders(
                    title: "Chromatic Aberration Boundaries",
                    minVal: $settings.minCABoundary, maxVal: $settings.maxCABoundary,
                    minAbsoluteRange: -100.0...100.0, maxAbsoluteRange: 0.0...200.0,
                    helpState: $showingCAHelp, helpText: "Fine-tune the optical lens RGB shift."
                )
            } header: {
                Text("CHROMATIC ABERRATION")
            }
            
            Section {
                boundarySliders(
                    title: "Sensitivity Boundaries",
                    minVal: $settings.minSensitivityBoundary, maxVal: $settings.maxSensitivityBoundary,
                    minAbsoluteRange: -50.0...50.0, maxAbsoluteRange: 0.1...100.0,
                    helpState: $showingGesturesHelp, helpText: "Scale the required speed for trackpad flicks."
                )
                
                boundarySliders(
                    title: "Cooldown Boundaries (Seconds)",
                    minVal: $settings.minCooldownBoundary, maxVal: $settings.maxCooldownBoundary,
                    minAbsoluteRange: -10.0...10.0, maxAbsoluteRange: 0.1...20.0,
                    helpState: .constant(false), helpText: ""
                )
            } header: {
                Text("GESTURES")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    @ViewBuilder
    func boundarySliders(
        title: String,
        minVal: Binding<Double>,
        maxVal: Binding<Double>,
        minAbsoluteRange: ClosedRange<Double>,
        maxAbsoluteRange: ClosedRange<Double>,
        helpState: Binding<Bool>,
        helpText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                
                if !helpText.isEmpty {
                    Button(action: { helpState.wrappedValue.toggle() }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: helpState) {
                        Text(helpText)
                            .padding()
                            .frame(maxWidth: 250)
                    }
                }
            }
            .padding(.bottom, 4)
            
            // Minimum Bound Slider
            HStack(spacing: 8) {
                Text("Min")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                
                Text("\(minAbsoluteRange.lowerBound, specifier: "%.1f")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 35, alignment: .trailing)
                
                ResetSlider(value: minVal, range: minAbsoluteRange, defaultValue: 0.0)
                    .onChange(of: minVal.wrappedValue) { newValue in
                        if newValue > maxVal.wrappedValue {
                            minVal.wrappedValue = maxVal.wrappedValue
                        }
                    }
                
                Text("\(minAbsoluteRange.upperBound, specifier: "%.1f")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 35, alignment: .leading)
                
                Text("\(minVal.wrappedValue, specifier: "%.2f")")
                    .font(.callout)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            
            // Maximum Bound Slider
            HStack(spacing: 8) {
                Text("Max")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                
                Text("\(maxAbsoluteRange.lowerBound, specifier: "%.1f")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 35, alignment: .trailing)
                
                ResetSlider(value: maxVal, range: maxAbsoluteRange, defaultValue: maxAbsoluteRange.upperBound)
                    .onChange(of: maxVal.wrappedValue) { newValue in
                        if newValue < minVal.wrappedValue {
                            maxVal.wrappedValue = minVal.wrappedValue
                        }
                    }
                
                Text("\(maxAbsoluteRange.upperBound, specifier: "%.1f")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 35, alignment: .leading)
                
                Text("\(maxVal.wrappedValue, specifier: "%.2f")")
                    .font(.callout)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
    }
}
import SwiftUI

struct ResetSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double
    
    // Snap threshold is 4% of the total range
    private var snapThreshold: Double {
        (range.upperBound - range.lowerBound) * 0.04
    }
    
    private var snappedBinding: Binding<Double> {
        Binding(
            get: { self.value },
            set: { newValue in
                if abs(newValue - defaultValue) < snapThreshold {
                    self.value = defaultValue
                } else {
                    self.value = newValue
                }
            }
        )
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // The track and thumb
                Slider(value: snappedBinding, in: range)
                    .onTapGesture(count: 2) {
                        // Double-click to reset
                        value = defaultValue
                    }
                
                // The default position dot
                let proportion = (defaultValue - range.lowerBound) / (range.upperBound - range.lowerBound)
                // Slider thumb has roughly 8px padding on each side
                let width = proxy.size.width - 16
                
                Circle()
                    .fill(Color.primary.opacity(0.4))
                    .frame(width: 4, height: 4)
                    .offset(x: 8 + width * proportion, y: 0)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 20)
    }
}
