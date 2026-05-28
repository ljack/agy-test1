import SwiftUI

struct MainView: View {
    @State private var modelLeft = FileManagerModel()
    @State private var modelRight = FileManagerModel()
    @State private var isDualPane: Bool = false
    @State private var activePane: ActivePane = .left
    
    enum ActivePane: Sendable {
        case left, right
    }
    
    var activeModel: FileManagerModel {
        (isDualPane && activePane == .right) ? modelRight : modelLeft
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(model: activeModel)
        } detail: {
            HSplitView {
                // Left Explorer Pane
                VStack(spacing: 0) {
                    ExplorerPane(model: modelLeft)
                }
                .overlay(
                    // Visual indicator for active pane in Dual Pane mode
                    Rectangle()
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: (isDualPane && activePane == .left) ? 2.5 : 0)
                )
                .onTapGesture {
                    activePane = .left
                }
                
                // Optional Right Explorer Pane
                if isDualPane {
                    VStack(spacing: 0) {
                        ExplorerPane(model: modelRight)
                    }
                    .overlay(
                        Rectangle()
                            .stroke(Color.accentColor.opacity(0.6), lineWidth: (isDualPane && activePane == .right) ? 2.5 : 0)
                    )
                    .onTapGesture {
                        activePane = .right
                    }
                }
                
                // Unified Preview Pane for active selection
                PreviewPane(model: activeModel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    isDualPane.toggle()
                    if isDualPane {
                        // Initialize right model to current path of left model
                        modelRight.navigateTo(url: modelLeft.currentDirectory)
                    }
                }) {
                    Label(isDualPane ? "Single Pane" : "Dual Pane", systemImage: isDualPane ? "rectangle.fill" : "square.split.2x1")
                }
                .help(isDualPane ? "Switch to Single Pane" : "Switch to Dual Pane")
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}
