public enum CodePack: String, Codable, CaseIterable, Sendable {
  case all, go, python, typescript, sql, shell

  public var label: String {
    switch self {
    case .all: "All"
    case .go: "Go"
    case .python: "Python"
    case .typescript: "TypeScript"
    case .sql: "SQL"
    case .shell: "Shell"
    }
  }

  public var next: CodePack {
    switch self {
    case .all: .go
    case .go: .python
    case .python: .typescript
    case .typescript: .sql
    case .sql: .shell
    case .shell: .all
    }
  }
}
