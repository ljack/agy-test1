# Agy Finder 🚀

Agy Finder is a lightweight, keyboard-first, and developer-centric macOS Finder replacement and enhancement built natively in **Swift** and **SwiftUI**. 

It features dual-pane layouts, live folder syncing, rich syntax-highlighted previews, and customizable sidebar shortcuts, all packaged in a modern, native macOS user experience.

---

## Key Features

*   **Keyboard & Vim Navigation**: Navigate folder trees entirely with arrow keys, or use standard Vim bindings (`h`/`j`/`k`/`l` to move, `o`/`Enter` to open).
*   **Dual-Pane Support**: Split your workspace vertically into side-by-side folder panels (toggle via the layout icon in the toolbar) for rapid file operations and comparisons.
*   **Recent History**: Sidebar history pane showing your recently visited directories.
*   **Dynamic Favorites**: Add folders to your sidebar Favorites directly from the context menu (right-click -> *Add to Favorites*). Favorites are saved across launches using `UserDefaults`.
*   **Live Updates**: Monitors active folders using GCD `DispatchSource` write observers, updating file list changes instantly.
*   **Rich Previews**: Scrollable monospaced preview for text, JSON, and source files directly in the inspector pane.

---

## Getting Started

### Prerequisites

*   macOS 14.0 or newer
*   Swift 6.0+ / Xcode 15.0+

### Compiling and Running Locally

Clone this repository and run the following commands in your terminal:

```bash
# Build the project
swift build

# Run the GUI application
swift run
```

### Build for Release Locally

To build a optimized release executable locally:

```bash
swift build -c release
```
The compiled binary will be placed under `.build/release/agy-test1`.

---

## How to Publish a Release

This project uses **GitHub Actions** to automate releases. Every time you push a version tag to the main branch, a new release is automatically compiled, packaged as a native macOS App Bundle, and published.

### Step-by-Step Publish Guide

1.  **Commit your changes** to the `main` branch.
2.  **Tag the commit** with a version matching `v*` (e.g., `v1.0.0`):
    ```bash
    git tag v1.0.0
    ```
3.  **Push the tag** to GitHub:
    ```bash
    git push origin v1.0.0
    ```
4.  **Monitor the Release**:
    *   Navigate to the **Actions** tab on your GitHub repository.
    *   Once the pipeline finishes, a new public release will be created under the **Releases** section.
    *   The release will contain `AgyFinder.zip`, which packages the double-clickable `AgyFinder.app` bundle. You can download, extract, and drag it directly to your `/Applications` folder!
