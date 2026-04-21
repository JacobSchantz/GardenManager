import SwiftUI

struct BeadRow: View {
    let bead: Bead

    var body: some View {
        HStack(spacing: 10) {
            // Priority badge
            Text(bead.priorityLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(priorityBackground)
                .clipShape(Capsule())

            // Type icon
            Image(systemName: bead.typeIcon)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(bead.title)
                    .font(.subheadline)
                    .lineLimit(2)

                if let repo = bead.repo {
                    HStack(spacing: 4) {
                        Image(systemName: repo.icon)
                            .font(.system(size: 9))
                        Text(repo.displayName)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(repoColor)
                }
            }

            Spacer()

            // Assignee
            if let assignee = bead.assignee, !assignee.isEmpty {
                Text(assignee)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var priorityBackground: Color {
        switch bead.priority {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        default: return .gray
        }
    }

    private var repoColor: Color {
        switch bead.repo?.color {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        default: return .secondary
        }
    }
}
