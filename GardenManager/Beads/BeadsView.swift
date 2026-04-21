import SwiftUI

struct BeadsView: View {
    @State private var client = BeadsClient()
    @State private var selectedRepo: Repo? = nil

    var body: some View {
        NavigationStack {
            Group {
                if client.isLoading && client.beads.isEmpty {
                    ProgressView("Loading beads…")
                } else if let error = client.errorMessage, client.beads.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if client.beads.isEmpty {
                    ContentUnavailableView("No Beads", systemImage: "circle", description: Text("No beads found."))
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

    private var displayedBeads: [Bead] {
        if let repo = selectedRepo {
            return client.beads.filter { $0.repo == repo }
        }
        return client.beads
    }

    private var beadsList: some View {
        List {
            // Repo picker
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        repoChip(repo: nil, label: "All", icon: "tray.full", count: client.beads.count)
                        ForEach(Repo.allCases) { repo in
                            let count = client.beads.filter { $0.repo == repo }.count
                            if count > 0 {
                                repoChip(repo: repo, label: repo.displayName, icon: repo.icon, count: count)
                            }
                        }
                    }
                }
            }

            let inProgress = displayedBeads.filter { $0.statusGroup == .inProgress }
            let notStarted = displayedBeads.filter { $0.statusGroup == .notStarted }
            let completed = displayedBeads.filter { $0.statusGroup == .completed }

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
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Bead.self) { bead in
            BeadDetailView(bead: bead)
        }
    }

    private func repoChip(repo: Repo?, label: String, icon: String, count: Int) -> some View {
        Button {
            selectedRepo = repo
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selectedRepo == repo ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
