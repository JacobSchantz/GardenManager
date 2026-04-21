import SwiftUI

struct BeadDetailView: View {
    let bead: Bead
    @State private var detail: Bead?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: bead.typeIcon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(bead.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(bead.title)
                            .font(.title3.weight(.semibold))
                    }
                }

                Divider()

                // Status
                DetailRow(label: "Status", value: bead.status) {
                    StatusBadge(status: bead.status)
                }

                // Priority
                DetailRow(label: "Priority", value: bead.priorityLabel) {
                    Text(bead.priorityLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(priorityColor)
                        .clipShape(Capsule())
                }

                // Type
                DetailRow(label: "Type", value: bead.issue_type) {
                    Label(bead.issue_type, systemImage: bead.typeIcon)
                        .font(.caption)
                }

                // Assignee
                if let assignee = bead.assignee {
                    DetailRow(label: "Assignee", value: assignee) {
                        Text(assignee).font(.caption)
                    }
                }

                // Dates
                if let created = bead.formattedCreatedDate {
                    DetailRow(label: "Created", value: created) {
                        Text(created).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let updated = bead.formattedUpdatedDate {
                    DetailRow(label: "Updated", value: updated) {
                        Text(updated).font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Dependencies
                if let dep = bead.dependency_count, dep > 0 {
                    DetailRow(label: "Dependencies", value: "\(dep)") {
                        Text("\(dep)").font(.caption)
                    }
                }
                if let dep = bead.dependent_count, dep > 0 {
                    DetailRow(label: "Dependents", value: "\(dep)") {
                        Text("\(dep)").font(.caption)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Bead Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }

    private var priorityColor: Color {
        switch bead.priority {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        default: return .gray
        }
    }

    private func loadDetail() async {
        // Detail already available from list; this is a placeholder for future `bd show` enrichment
        detail = bead
    }
}

private struct DetailRow<Content: View>: View {
    let label: String
    let value: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(status)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case "in_progress": return .yellow
        case "closed": return .green
        default: return .gray
        }
    }
}
