import Foundation

struct Bead: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let status: String
    let priority: Int
    let issue_type: String
    let assignee: String?
    let owner: String?
    let created_at: String?
    let created_by: String?
    let updated_at: String?
    let started_at: String?
    let dependency_count: Int?
    let dependent_count: Int?
    let comment_count: Int?

    enum StatusGroup {
        case inProgress, completed, notStarted
    }

    var statusGroup: StatusGroup {
        switch status {
        case "in_progress": return .inProgress
        case "closed": return .completed
        default: return .notStarted
        }
    }

    var priorityLabel: String {
        "P\(priority)"
    }

    var priorityColor: String {
        switch priority {
        case 0: return "red"
        case 1: return "orange"
        case 2: return "yellow"
        default: return "gray"
        }
    }

    var typeIcon: String {
        switch issue_type {
        case "bug": return "ladybug"
        case "feature": return "sparkles"
        case "task": return "checkmark.circle"
        case "epic": return "star"
        case "chore": return "wrench"
        default: return "circle"
        }
    }

    var formattedCreatedDate: String? {
        guard let s = created_at else { return nil }
        return formatDate(s)
    }

    var formattedUpdatedDate: String? {
        guard let s = updated_at else { return nil }
        return formatDate(s)
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }
}
