import SwiftUI
import UniformTypeIdentifiers

struct PreviewPane: View {
    var model: FileManagerModel
    
    var body: some View {
        VStack(spacing: 0) {
            if let item = model.selectedItem {
                ScrollView {
                    VStack(alignment: .center, spacing: 16) {
                        // Large Icon / Thumbnail
                        FileThumbnailView(item: item)
                            .frame(height: 120)
                            .padding(.top, 20)
                        
                        // File Name and Extension
                        VStack(spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)
                            
                            if !item.isDirectory {
                                Text(item.fileExtension.uppercased() + " Document")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Folder")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Metadata Info
                        VStack(alignment: .leading, spacing: 8) {
                            MetadataRow(label: "Size", value: item.formattedSize)
                            MetadataRow(label: "Modified", value: item.formattedDate)
                            MetadataRow(label: "Path", value: item.url.path)
                        }
                        .font(.callout)
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Dynamic Content Preview (if text or image)
                        ContentPreviewView(item: item)
                            .frame(minHeight: 150, maxHeight: 300)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                }
                
                // Bottom Quick Action Buttons
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        Button(action: { model.openItem(item) }) {
                            Label("Open", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: { model.revealInFinder(item) }) {
                            Image(systemName: "magnifyingglass")
                                .help("Reveal in Finder")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { model.openInTerminal(item.isDirectory ? item.url : item.url.deletingLastPathComponent()) }) {
                            Image(systemName: "terminal")
                                .help("Open in Terminal")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { model.moveToTrash(item) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .help("Move to Trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "info.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Select a file or folder to preview details.")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            }
        }
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .foregroundColor(.primary)
                .lineLimit(5)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

struct FileThumbnailView: View {
    let item: FileItem
    
    var body: some View {
        if !item.isDirectory,
           let nsImage = NSImage(contentsOf: item.url),
           let _ = nsImage.representations.first {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
                .shadow(radius: 4)
        } else {
            Image(systemName: item.iconName)
                .resizable()
                .scaledToFit()
                .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                .frame(width: 80, height: 80)
        }
    }
}

struct ContentPreviewView: View {
    let item: FileItem
    
    var body: some View {
        if item.isDirectory {
            VStack {
                Text("Directory Contents")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else if isTextFile(item) {
            ScrollView {
                Text(readTextPreview(url: item.url))
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    .textSelection(.enabled)
            }
        } else {
            VStack {
                Spacer()
                Text("No preview available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
    
    private func isTextFile(_ item: FileItem) -> Bool {
        let ext = item.fileExtension.lowercased()
        let textExtensions = ["txt", "md", "swift", "py", "js", "ts", "json", "yaml", "yml", "xml", "csv", "sh", "c", "cpp", "h", "go", "rs", "gitignore", "log"]
        return textExtensions.contains(ext)
    }
    
    private func readTextPreview(url: URL) -> String {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let previewSize = min(data.count, 8 * 1024) // 8KB
            let subdata = data.subdata(in: 0..<previewSize)
            if let text = String(data: subdata, encoding: .utf8) {
                return text
            }
            return "Binary file or unsupported encoding"
        } catch {
            return "Error loading preview: \(error.localizedDescription)"
        }
    }
}
