import SwiftUI

struct MainView: View {
    @State private var modelLeft = FileManagerModel()
    @State private var modelRight = FileManagerModel()
    @State private var isDualPane: Bool = false
    @State private var activePane: ActivePane = .left
    
    enum ActivePane: Sendable {
        case left, right
    }
    
    enum FocusablePane: Hashable, Sendable {
        case leftList
        case rightList
        case leftPath
        case rightPath
        case leftSearch
        case rightSearch
    }
    
    @FocusState private var focusedPane: FocusablePane?
    
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
                    ExplorerPane(model: modelLeft, isFocused: $focusedPane, paneType: .leftList)
                }
                .overlay(
                    // Visual indicator for active pane in Dual Pane mode
                    Rectangle()
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: (isDualPane && activePane == .left) ? 2.5 : 0)
                )
                .onTapGesture {
                    activePane = .left
                    focusedPane = .leftList
                }
                
                // Optional Right Explorer Pane
                if isDualPane {
                    VStack(spacing: 0) {
                        ExplorerPane(model: modelRight, isFocused: $focusedPane, paneType: .rightList)
                    }
                    .overlay(
                        Rectangle()
                            .stroke(Color.accentColor.opacity(0.6), lineWidth: (isDualPane && activePane == .right) ? 2.5 : 0)
                    )
                    .onTapGesture {
                        activePane = .right
                        focusedPane = .rightList
                    }
                }
                
                // Unified Preview Pane for active selection
                PreviewPane(model: activeModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedPane = nil
                    }
            }
            .onAppear {
                setupOpenInOtherPaneCallbacks()
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
        .onKeyPress { press in
            handleGlobalKeyPress(press)
        }
        .frame(minWidth: 800, minHeight: 500)
    }
    
    private func setupOpenInOtherPaneCallbacks() {
        modelLeft.onOpenInOtherPane = { url in
            if !isDualPane {
                isDualPane = true
                // Defer navigation until right pane is instantiated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    modelRight.navigateTo(url: url)
                    activePane = .right
                    focusedPane = .rightList
                }
            } else {
                modelRight.navigateTo(url: url)
                activePane = .right
                focusedPane = .rightList
            }
        }
        modelRight.onOpenInOtherPane = { url in
            modelLeft.navigateTo(url: url)
            activePane = .left
            focusedPane = .leftList
        }
    }
    
    private func handleGlobalKeyPress(_ press: KeyPress) -> KeyPress.Result {
        // Only intercept key presses if neither list has direct keyboard focus
        guard focusedPane == nil else { return .ignored }
        
        let models = isDualPane ? [modelLeft, modelRight] : [modelLeft]
        let isAnyFiltering = models.contains { $0.isFilterActive }
        
        if isAnyFiltering {
            if press.key == .escape {
                for m in models {
                    m.filterText = ""
                    m.isFilterActive = false
                }
                return .handled
            }
            if press.key == .delete || press.characters.first == "\u{7F}" || press.characters.first == "\u{08}" {
                for m in models {
                    if !m.filterText.isEmpty {
                        m.filterText.removeLast()
                    }
                    if m.filterText.isEmpty {
                        m.isFilterActive = false
                    }
                }
                return .handled
            }
            if press.key == .return {
                for m in models {
                    if let selected = m.selectedItem {
                        m.openItem(selected)
                    }
                    m.filterText = ""
                    m.isFilterActive = false
                }
                return .handled
            }
            if press.isPrintableCharacter {
                for m in models {
                    m.isFilterActive = true
                    m.filterText.append(press.characters)
                }
                return .handled
            }
            return .ignored
        } else {
            // Trigger filter mode globally
            if press.modifiers.subtracting(.shift).isEmpty && press.characters == "/" {
                for m in models {
                    m.isFilterActive = true
                    m.filterText = ""
                }
                return .handled
            }
            if press.isPrintableCharacter {
                // If it's a Vim key, don't start search globally unless they type /
                // (This keeps keys like j/k from starting search when just browsing globally)
                let isVimKey = ["j", "k", "h", "l", "o", "v"].contains(press.characters)
                if !isVimKey {
                    for m in models {
                        m.isFilterActive = true
                        m.filterText = press.characters
                    }
                    return .handled
                }
            }
            return .ignored
        }
    }
}
