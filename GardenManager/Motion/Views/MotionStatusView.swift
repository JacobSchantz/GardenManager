import SwiftUI

struct MotionStatusView: View {
    @EnvironmentObject var motionTracker: MotionTracker
    
    @State private var showingThresholdSlider = false
    @State private var tempThreshold: Double = 0.03
    
    var body: some View {
        NavigationView {
            Form {
                Section("Current Status") {
                    LabeledContent("Has moved recently") {
                        Text(motionTracker.hasMovedRecently ? "Yes" : "No")
                            .foregroundStyle(motionTracker.hasMovedRecently ? .green : .red)
                    }
                    
                    LabeledContent("Last movement") {
                        if let date = motionTracker.lastMovementDate {
                            Text(date.formatted(date: .abbreviated, time: .standard))
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Real-time Data") {
                    LabeledContent("Magnitude") {
                        Text(String(format: "%.3f", motionTracker.currentMagnitude))
                    }
                    
                    LabeledContent("Last Change") {
                        Text(String(format: "%.3f", motionTracker.lastMagnitudeChange))
                            .foregroundStyle(motionTracker.lastMagnitudeChange > motionTracker.movementThreshold ? .green : .secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Acceleration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("X: \(String(format: "%.3f", motionTracker.currentAcceleration.x))")
                            Spacer()
                            Text("Y: \(String(format: "%.3f", motionTracker.currentAcceleration.y))")
                            Spacer()
                            Text("Z: \(String(format: "%.3f", motionTracker.currentAcceleration.z))")
                        }
                        .font(.caption.monospaced())
                    }
                }
                
                Section("Configuration") {
                    LabeledContent("Recent window (s)") {
                        Text(String(format: "%.0f", motionTracker.recentWindow))
                    }
                    
                    LabeledContent("Movement threshold") {
                        HStack {
                            Text(String(format: "%.3f", motionTracker.movementThreshold))
                            Spacer()
                            Button("Adjust") {
                                tempThreshold = motionTracker.movementThreshold
                                showingThresholdSlider = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                Section("Motion Events") {
                    if motionTracker.motionEvents.isEmpty {
                        Text("No events yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(motionTracker.motionEvents.reversed().enumerated()), id: \.element.id) { index, event in
                            HStack {
                                Image(systemName: event.type.icon)
                                    .foregroundStyle(Color(event.type.color))
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.type.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Text(event.date.formatted(date: .omitted, time: .standard))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.3f", event.value))
                                        .font(.caption.monospaced())
                                        .fontWeight(.medium)
                                    
                                    if event.type != .thresholdChanged {
                                        Text("(\(String(format: "%.2f", event.acceleration.x)), \(String(format: "%.2f", event.acceleration.y)), \(String(format: "%.2f", event.acceleration.z)))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Motion")
            .sheet(isPresented: $showingThresholdSlider) {
                ThresholdSliderView(
                    currentThreshold: $tempThreshold,
                    onConfirm: {
                        motionTracker.movementThreshold = tempThreshold
                        showingThresholdSlider = false
                    },
                    onCancel: {
                        showingThresholdSlider = false
                    }
                )
            }
        }
    }
}

struct ThresholdSliderView: View {
    @Binding var currentThreshold: Double
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Movement Threshold")
                            .font(.headline)
                        
                        Text("Adjust the sensitivity of motion detection. Lower values detect smaller movements, higher values require more significant movement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Current:")
                                Spacer()
                                Text(String(format: "%.3f", currentThreshold))
                                    .fontWeight(.medium)
                            }
                            
                            Slider(value: $currentThreshold, in: 0.001...0.1, step: 0.001)
                            
                            HStack {
                                Text("Less Sensitive")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("More Sensitive")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section("Presets") {
                    ForEach([0.005, 0.01, 0.02, 0.03, 0.05, 0.1], id: \.self) { preset in
                        Button(action: { currentThreshold = preset }) {
                            HStack {
                                Text(preset == 0.005 ? "Very Sensitive" :
                                     preset == 0.01 ? "Sensitive" :
                                     preset == 0.02 ? "Normal" :
                                     preset == 0.03 ? "Less Sensitive" :
                                     preset == 0.05 ? "Dull" : "Very Dull")
                                Spacer()
                                Text(String(format: "%.3f", preset))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Adjust Threshold")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onConfirm)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
