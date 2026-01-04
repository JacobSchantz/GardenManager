import SwiftUI
import Charts

struct MotionStatusView: View {
    @EnvironmentObject var motionTracker: MotionTracker
    
    @State private var showingThresholdSlider = false
    @State private var tempThreshold: Double = 0.03
    
    var body: some View {
        NavigationView {
            List {
                // Current Status Section
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
                
                // Real-time Data Section
                Section("Real-time Data") {
                    LabeledContent("Total Velocity (5s)") {
                        Text(String(format: "%.3f", motionTracker.totalVelocityLast5Seconds))
                            .foregroundStyle(motionTracker.totalVelocityLast5Seconds > motionTracker.movementThreshold ? .green : .secondary)
                    }
                }
                
                // Configuration Section
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
