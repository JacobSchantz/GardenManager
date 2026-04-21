import SwiftUI

struct BeadsView: View {
    @State private var client = BeadsClient()

    var body: some View {
        NavigationStack {
            Group {
                if client.isLoading && client.beads.isEmpty {
                    ProgressView("Loading beads…")
                } else if let error = client.errorMessage, client.beads.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if client.beads.isEmpty {
                    ContentUnavailableView("No Beads", systemImage: "circle", description: Text("No beads found in this project."))
                } else {
                    beadsList
                }
            }
            .navigationTitle("Beads")
            .refreshable {
                await client.fetchBeads()
            }
            .task {
                await client.fetchBeads()
                client.startAutoRefresh()
            }
            .onDisappear {
                client.stopAutoRefresh()
            }
        }
    }

    private var beadsList: some View {
        List {
            let inProgress = client.beads.filter { $0.statusGroup == .inProgress }
            let completed = client.beads.filter { $0.statusGroup == .completed }
            let notStarted = client.beads.filter { $0.statusGroup == .notStarted }

            if !inProgress.isEmpty {
                Section {
                    ForEach(inProgress) { bead in
                        NavigationLink(value: bead) {
                            BeadRow(bead: bead)
                        }
                        .listRowBackground(Color.yellow.opacity(0.05))
                    }
                } header: {
                    sectionHeader(icon: "circle.fill", color: .yellow, title: "In Progress", count: inProgress.count)
                }
            }

            if !completed.isEmpty {
                Section {
                    ForEach(completed) { bead in
                        NavigationLink(value: bead) {
                            BeadRow(bead: bead)
                        }
                        .listRowBackground(Color.green.opacity(0.05))
                    }
                } header: {
                    sectionHeader(icon: "checkmark.circle.fill", color: .green, title: "Completed", count: completed.count)
                }
            }

            if !notStarted.isEmpty {
                Section {
                    ForEach(notStarted) { bead in
                        NavigationLink(value: bead) {
                            BeadRow(bead: bead)
                        }
                    }
                } header: {
                    sectionHeader(icon: "circle", color: .gray, title: "Not Started", count: notStarted.count)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Bead.self) { bead in
            BeadDetailView(bead: bead)
        }
    }

    private func sectionHeader(icon: String, color: Color, title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            Text(title)
            Text("(\(count))")
                .foregroundStyle(.secondary)
        }
    }
}
