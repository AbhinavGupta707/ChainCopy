import Foundation

enum SeparatorPreset: String, CaseIterable, Identifiable {
    case blankLine
    case newLine
    case space
    case comma
    case markdownDivider
    case bullets
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blankLine:
            return "Blank Line"
        case .newLine:
            return "New Line"
        case .space:
            return "Space"
        case .comma:
            return "Comma"
        case .markdownDivider:
            return "Markdown Divider"
        case .bullets:
            return "Bullets"
        case .custom:
            return "Custom"
        }
    }

    var compactTitle: String {
        switch self {
        case .blankLine:
            return "Blank"
        case .newLine:
            return "Line"
        case .space:
            return "Space"
        case .comma:
            return "Comma"
        case .markdownDivider:
            return "Divider"
        case .bullets:
            return "Bullets"
        case .custom:
            return "Custom"
        }
    }

    var separator: String {
        switch self {
        case .blankLine:
            return "\n\n"
        case .newLine:
            return "\n"
        case .space:
            return " "
        case .comma:
            return ", "
        case .markdownDivider:
            return "\n\n---\n\n"
        case .bullets:
            return "\n- "
        case .custom:
            return "\n\n"
        }
    }

    var preview: String {
        switch self {
        case .blankLine:
            return "Alpha\\n\\nBeta"
        case .newLine:
            return "Alpha\\nBeta"
        case .space:
            return "Alpha Beta"
        case .comma:
            return "Alpha, Beta"
        case .markdownDivider:
            return "Alpha\\n---\\nBeta"
        case .bullets:
            return "- Alpha\\n- Beta"
        case .custom:
            return "User defined"
        }
    }

    static func matching(_ separator: String) -> SeparatorPreset {
        switch separator {
        case SeparatorPreset.blankLine.separator:
            return .blankLine
        case SeparatorPreset.newLine.separator:
            return .newLine
        case SeparatorPreset.space.separator:
            return .space
        case SeparatorPreset.comma.separator:
            return .comma
        case SeparatorPreset.markdownDivider.separator:
            return .markdownDivider
        case SeparatorPreset.bullets.separator:
            return .bullets
        default:
            return .custom
        }
    }
}
