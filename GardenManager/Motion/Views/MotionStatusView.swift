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
                        Text(String(format: "%.3f", motionTracker.totalVelocity))
                    }
                }
                
                // Motion Events Section

                ForEach(motionTracker.motionEvents) { event in
                    VStack{
                        Text("X: \(String(format: "%.3f", event.timestamp.timeIntervalSince1970))")
                        HStack {
                            Text("X: \(String(format: "%.3f", event.acceleration.x))")
                            Spacer()
                            Text("Y: \(String(format: "%.3f", event.acceleration.y))")
                            Spacer()
                            Text("Z: \(String(format: "%.3f", event.acceleration.z))")
                        }
                    }
        
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .cornerRadius(6)
                    .animation(nil)
                }
                
                
                // Configuration Section
                Section("Configuration") {
                    LabeledContent("Recent window (s)") {
                        Text(String(format: "%.0f", motionTracker.secondsBetweenCalculations))
                    }
                    
                    LabeledContent("Movement threshold") {
                        HStack {
                            Text(String(format: "%.3f", motionTracker.minimumVelocity))
                            Spacer()
                            Button("Adjust") {
                                tempThreshold = motionTracker.minimumVelocity
                                showingThresholdSlider = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                    }
                }
            }
            .padding()
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
                            .multilineTextAlignment(.leading)
                        
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
                        .tint(.blue)
                    }
                }
            }
            .padding()
            .navigationTitle("Adjust Threshold")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MotionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        MotionStatusView()
    }
}
