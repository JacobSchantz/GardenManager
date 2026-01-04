import SwiftUI
import Charts

struct MotionGraphsView: View {
    @EnvironmentObject var motionTracker: MotionTracker
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Position Graphs
                    VStack(alignment: .leading) {
                        Text("Position (m)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // X Position
                        Chart {
                            ForEach(Array(motionTracker.getPositionHistory().enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("Time", point.timestamp, unit: .second),
                                    y: .value("X", point.x)
                                )
                                .foregroundStyle(.red)
                            }
                        }
                        .frame(height: 150)
                        .padding()
                        .chartXAxis {
                            AxisMarks(position: .bottom)
                        }
                        
                        // Y Position
                        Chart {
                            ForEach(Array(motionTracker.getPositionHistory().enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("Time", point.timestamp, unit: .second),
                                    y: .value("Y", point.y)
                                )
                                .foregroundStyle(.green)
                            }
                        }
                        .frame(height: 150)
                        .padding()
                        
                        // Z Position
                        Chart {
                            ForEach(Array(motionTracker.getPositionHistory().enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("Time", point.timestamp, unit: .second),
                                    y: .value("Z", point.z)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .frame(height: 150)
                        .padding()
                    }
                    
                    // Current Values
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Position (m)")
                            .font(.headline)
                        
                        HStack {
                            Text("X: \(String(format: "%.2f", motionTracker.currentPosition.x))")
                                .foregroundColor(.red)
                            Spacer()
                            Text("Y: \(String(format: "%.2f", motionTracker.currentPosition.y))")
                                .foregroundColor(.green)
                            Spacer()
                            Text("Z: \(String(format: "%.2f", motionTracker.currentPosition.z))")
                                .foregroundColor(.blue)
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                    .padding()
                }
                .padding(.vertical)
            }
            .navigationTitle("Motion Graphs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        motionTracker.resetPosition()
                        motionTracker.resetVelocity()
                    }
                }
            }
        }
    }
}
