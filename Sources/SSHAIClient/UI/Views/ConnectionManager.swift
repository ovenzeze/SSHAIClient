import SwiftUI
import Combine

// MARK: - Models

public struct SSHConnectionUI: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var group: String?
    public var tags: [String]
    public var isFavorite: Bool
    public var lastConnected: Date?

    public init(id: UUID = UUID(), name: String, host: String, port: Int = 22, username: String, group: String? = nil, tags: [String] = [], isFavorite: Bool = false, lastConnected: Date? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.group = group
        self.tags = tags
        self.isFavorite = isFavorite
        self.lastConnected = lastConnected
    }
}

// MARK: - ViewModel

@available(macOS 11.0, *)
public final class ConnectionManagerViewModel: ObservableObject {
    @Published public var connections: [SSHConnectionUI]
    @Published public var searchText: String = ""
    @Published public var selectedConnection: SSHConnectionUI?

    public init(connections: [SSHConnectionUI] = []) {
        // Demo seed
        if connections.isEmpty {
            self.connections = [
                SSHConnectionUI(name: "Prod Web", host: "prod.web.example.com", username: "ec2-user", group: "Production", tags: ["web", "nginx"], isFavorite: true),
                SSHConnectionUI(name: "Prod DB", host: "prod.db.example.com", username: "postgres", group: "Production", tags: ["db", "postgres"], isFavorite: false),
                SSHConnectionUI(name: "Staging", host: "stg.example.com", username: "deploy", group: "Staging", tags: ["stg"], isFavorite: false),
                SSHConnectionUI(name: "Dev Mac Mini", host: "192.168.1.20", username: "clay", group: "Personal", tags: ["dev"], isFavorite: true)
            ]
        } else {
            self.connections = connections
        }
    }

    public var filteredConnections: [SSHConnectionUI] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return connections }
        return connections.filter { c in
            c.name.localizedCaseInsensitiveContains(term) ||
            c.host.localizedCaseInsensitiveContains(term) ||
            c.username.localizedCaseInsensitiveContains(term) ||
            c.group?.localizedCaseInsensitiveContains(term) == true ||
            c.tags.contains(where: { $0.localizedCaseInsensitiveContains(term) })
        }
    }

    public var grouped: [(String, [SSHConnectionUI]) ] {
        let groups = Dictionary(grouping: filteredConnections) { (c: SSHConnectionUI) in
            if c.isFavorite { return "★ Favorites" }
            return c.group ?? "Ungrouped"
        }
        return groups.keys.sorted().map { ($0, groups[$0]!.sorted { $0.name < $1.name }) }
    }
}

// MARK: - Views

@available(macOS 11.0, *)
public struct ConnectionManager: View {
    @ObservedObject var viewModel: ConnectionManagerViewModel
    public var onConnect: (SSHConnectionUI) -> Void

    public init(viewModel: ConnectionManagerViewModel = ConnectionManagerViewModel(), onConnect: @escaping (SSHConnectionUI) -> Void) {
        self.viewModel = viewModel
        self.onConnect = onConnect
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search
            SearchBar(text: $viewModel.searchText, placeholder: "Search connections (⌘F)")
                .padding(8)
                .background(Color(PlatformColor.controlBackgroundColor))

            Divider()

            // List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(viewModel.grouped.indices), id: \.self) { idx in
                        let group = viewModel.grouped[idx]
                        let groupName = group.0
                        let items = group.1
                        Section(header: Text(groupName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 12)) {
                                ForEach(items) { item in
                                    ConnectionRow(item: item,
                                                  isSelected: item.id == viewModel.selectedConnection?.id,
                                                  onConnect: { onConnect(item) })
                                        .onTapGesture { withAnimation(.easeInOut) { viewModel.selectedConnection = item } }
                                        .contextMenu {
                                            Button("Connect") { onConnect(item) }
                                            Button(item.isFavorite ? "Unfavorite" : "Favorite") {
                                                toggleFavorite(item)
                                            }
                                            Divider()
                                            Button("Copy Host") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.host, forType: .string) }
                                        }
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(PlatformColor.windowBackgroundColor))
        .accessibilityLabel(Text("Connection Manager"))
    }

    private func toggleFavorite(_ item: SSHConnectionUI) {
        if let idx = viewModel.connections.firstIndex(of: item) {
            viewModel.connections[idx].isFavorite.toggle()
        }
    }
}

@available(macOS 11.0, *)
private struct ConnectionRow: View {
    let item: SSHConnectionUI
    var isSelected: Bool
    var onConnect: () -> Void
    @Namespace private var highlight
    @State private var isHover = false

    var body: some View {
        HStack(spacing: 10) {
            // Favorite indicator (star) for clearer semantics
            if item.isFavorite {
                Image(systemName: "star.fill").foregroundColor(.yellow).font(.system(size: 10))
            } else {
                Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let g = item.group { TagView(text: g) }
                }
                Text("\(item.username)@\(item.host):\(item.port)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .modifier(TextSelectionModifier())
            }
            Spacer()
            Button(action: onConnect) {
                Image(systemName: "terminal")
            }
            .buttonStyle(.plain)
            .help("Connect")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack(alignment: .leading) {
                let base = isSelected ? Color.accentColor.opacity(0.16) : (isHover ? Color.primary.opacity(0.06) : Color.clear)
                RoundedRectangle(cornerRadius: 6).fill(base)
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                        .matchedGeometryEffect(id: "row-select", in: highlight)
                }
            }
        )
        .cornerRadius(6)
        .onHover { isHover = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(item.name), host \(item.host)"))
        .accessibilityHint(Text("Press Enter to connect"))
    }
}

@available(macOS 11.0, *)
private struct TagView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundColor(Color.primary.opacity(0.9))
            .background(Color.white.opacity(0.12))
            .cornerRadius(4)
            .accessibilityHidden(true)
    }
}
