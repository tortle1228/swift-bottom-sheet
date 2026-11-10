# BottomSheetKit

[English](README.md) | [한국어](README.ko.md)

A SwiftUI bottom sheet for forms, selections, and explanations that should fit their content. It uses a custom UIKit presentation, moves above a docked keyboard, and scrolls content that exceeds the available height.

## Requirements and installation

- iOS 17 or later; Swift tools 6.0 and Swift 6 language mode.
- Xcode with an iOS SDK and Swift 6 support. The geometry example below uses the single-value `onGeometryChange` API available in Xcode 16 and later.
- One library product and import: `BottomSheetKit`. No runtime package dependencies.

**Availability:** this README describes the local implementation through `87a8704`. At the documentation check on November 11, 2026, remote `main` was still `c30bcf2`; `maximumWidth` and `bottomSheetContentHeight(_:)` were not yet pushed. Use a local checkout containing `87a8704` for all examples below. A fresh remote clone does not yet contain those additions.

In your app's Xcode project, choose **File → Add Package Dependencies → Add Local**, select this repository's folder (the one containing `Package.swift`), and add the **BottomSheetKit** product to your app target.

For remote installation, you need access to the private [swift-bottom-sheet repository](https://github.com/tortle1228/swift-bottom-sheet) and a GitHub account configured in Xcode with that access. Enter `https://github.com/tortle1228/swift-bottom-sheet.git` in Add Package Dependencies, choose the **main** branch, and add **BottomSheetKit** to your app target. No version tags are currently provided. Verify that the remote branch contains the APIs you intend to use before switching from a local dependency.

Apple documents [local package dependencies](https://developer.apple.com/documentation/xcode/editing-a-package-dependency-as-a-local-package) and [remote package installation](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

## Show and close a sheet

Place `SheetExample()` in your app's view hierarchy. Tapping Show sheet presents the content; Close dismisses it and resets the binding to `false`.

```swift
import BottomSheetKit
import SwiftUI

struct SheetExample: View {
    @State private var isPresented = false

    var body: some View {
        Button("Show sheet") { isPresented = true }
            .bottomSheet(isPresented: $isPresented) {
                WelcomeSheet()
            }
    }
}

private struct WelcomeSheet: View {
    @Environment(\.bottomSheetDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome").font(.title2)
            Text("This sheet fits its content.")
            Button("Close") { dismiss() }
        }
    }
}
```

The presentation binding owns the state. You can also close the sheet by setting that binding to `false`. Attach the modifier to a stable view. The environment action is `bottomSheetDismiss`, not the system sheet's `dismiss` action.

## Item presentation and dismissal lifecycle

```swift
import BottomSheetKit
import SwiftUI

private struct SelectedItem: Identifiable {
    let id: Int
    var title: String
}

struct ItemSheetExample: View {
    @State private var item: SelectedItem?
    @State private var dismissalCount = 0

    var body: some View {
        Button("Show item") { item = SelectedItem(id: 1, title: "First item") }
            .bottomSheet(item: $item, onDismiss: { dismissalCount += 1 }) { value in
                VStack(spacing: 16) {
                    Text(value.title)
                    Button("Update") { item?.title = "Updated item" }
                    Button("Replace") { item = SelectedItem(id: 2, title: "Next item") }
                    Button("Close") { item = nil }
                }
            }
    }
}
```

Updating an item with the same ID refreshes content in place and preserves its local SwiftUI state. Changing the ID dismisses the old sheet before presenting the replacement, whose local state starts fresh. Dismissing an old item does not clear a newer item with a different ID.

`onDismiss` runs once per completed dismissal, after the transition. Binding clearing happens when dismissal is requested. Use `onDismiss` to present a follow-up screen; replacing an item also completes a dismissal.

For dismissal outside the content hierarchy, pass an optional `id: BottomSheetID("account")` to either modifier, then call `BottomSheetPresenter.shared.dismiss(id: BottomSheetID("account"))` on the main actor. This registry only dismisses; it does not present sheets. IDs must be unique across simultaneously presented sheets, including different windows. Duplicate active IDs reject the new presentation and reset its binding. Unknown IDs and repeated dismissal requests do nothing.

## Height, width, and scrolling

The panel fits its content until it reaches the space between the top safe area plus 12 points and the screen bottom or the top of a docked keyboard. There is no public maximum-height or detent setting. Bottom safe-area space is added once when the keyboard is absent.

- `.automatic` (default) wraps ordinary content in a UIKit scroll view. Overflow scrolls inside the capped panel. Do not nest your own vertical scroll view in this mode.
- `.content` lets your content own scrolling, such as a `ScrollView` or `List`. Without a height report, the panel fills the available height.
- In `.content` mode, attach `bottomSheetContentHeight(_:)` once to the sheet content to request its natural height. Measure the contents inside the scroll view, including their own padding, rather than the viewport. The kit adds configured content padding, grabber space, and the bottom safe area. The example sets kit padding to zero because the content supplies its own.
- Nil, nonpositive, or nonfinite reported heights restore the available height. `.automatic` ignores the report. Changes resize the existing content; oversized content still needs its own scrolling.

`maximumWidth` defaults to nil (available horizontal safe-area width). A positive finite value limits width and centers the panel. Values larger than available space are clamped; nonpositive and nonfinite values are ignored. There is no fixed iPad width by default.

```swift
import BottomSheetKit
import SwiftUI

struct ScrollingSheetExample: View {
    @State private var isPresented = false

    private var configuration: BottomSheetConfiguration {
        var value = BottomSheetConfiguration()
        value.maximumWidth = 600
        value.contentScrolling = .content
        value.contentInsets = EdgeInsets()
        return value
    }

    var body: some View {
        Button("Show details") { isPresented = true }
            .bottomSheet(isPresented: $isPresented, configuration: configuration) {
                DetailsSheet()
            }
    }
}

private struct DetailsSheet: View {
    @State private var contentHeight: CGFloat = 0
    @Environment(\.bottomSheetDismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<20) { index in
                    Text("Detail \(index)")
                }
                Button("Close") { dismiss() }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                contentHeight = height
            }
        }
        .bottomSheetContentHeight(contentHeight)
    }
}
```

This measurement example uses an eager `VStack` so the full content height is known. For a large lazy list, keep the full-height `.content` behavior or supply a height derived from your data rather than measuring only realized rows.

## Configuration and integration notes

Create a `BottomSheetConfiguration`, set its properties, and pass it as `configuration:`. Dimensions are in points.

| Property | Default |
| --- | --- |
| `maximumWidth` | `nil` (available width) |
| `cornerRadius` | `32`, top corners |
| `backgroundColor` | System background; continues behind docked keyboard corners |
| `showsGrabber` | `true` |
| `grabberSize` / `grabberColor` | `40 × 5` / secondary system gray |
| `grabberInsets` | Top `8`, bottom `20`, leading/trailing `0` |
| `contentInsets` | Top `0`, leading/trailing `20`, bottom `32` |
| `dimmingColor` / `dimmingOpacity` | Black / `0.5`; opacity clamped to `0...1` |
| `dismissesOnBackdropTap` / `dismissesOnDrag` | `true` / `true` |
| `contentScrolling` | `.automatic` |

Set both dismissal flags to `false` while submitting to disable backdrop taps, grabber dismissal, and accessibility escape. Explicit binding, environment, and ID-based dismissal remain available. Drag dismissal starts from the grabber; this is not a draggable detent system.

Text size, color scheme, locale, and layout direction are inherited from the presenting view. Inject other environment values and objects explicitly **inside the sheet content closure**. The [form sample](Examples/Sample/ContentSizedForm.swift) and its [presenter](Examples/Sample/SampleApp.swift) show observable environment injection, focus, keyboard handling, dynamic height, submission locks, and a nested system modal.

The kit supports Dynamic Type, VoiceOver modal focus and escape, and Reduce Motion. Keep your content accessible and scrollable at large text sizes. It does not provide global presentation, a popup stack, or SwiftUI system sheet detents. Keyboard movement follows docked keyboards; floating keyboard overlap is not avoided automatically.

## Run the sample and contribute

Open [Examples/BottomSheetSample.xcodeproj](Examples/BottomSheetSample.xcodeproj), select **BottomSheetSample**, and run on an iOS simulator. Signing is disabled in the checked-in project. Available launch arguments in the scheme's Run action:

| Argument | Result |
| --- | --- |
| `-showInput` | Open the basic input sheet |
| `-showForm` | Open the content-sized form (600-point maximum width) |
| `-focusForm` | Focus the form email field; use with `-showForm` |
| `-accessibilityText` | Request the largest accessibility text size; the form deliberately caps its content at `accessibility1` |

For repository development, install SwiftLint **0.65.1** and select an Xcode toolchain containing `swift-format`. Run from the repository root:

```sh
scripts/bootstrap
scripts/lint
scripts/check
```

Bootstrap enables this repository's local Git hooks. `scripts/check` runs lint, hook self-checks, package tests, and sample UI tests. It chooses the first available iPhone simulator unless you set `SIMULATOR_ID`. Use `scripts/format` explicitly when formatting source. The UIKit package tests require an iOS simulator; macOS `swift test` is not the test entry point. XcodeGen is needed only when regenerating the sample after changes to `Examples/project.yml`, not to open the checked-in project. See [working rules](AGENTS.md) and the [CI workflow](.github/workflows/check.yml).

The implementation at `87a8704` passed lint, hook checks, 16 unit tests, and 11 UI tests, with additional small-iPhone and iPad layout checks. It compiled for an iOS 17 deployment target in Swift 6 mode; runtime checks used iOS 27.2 simulators. These checks do not establish iOS 17 runtime or physical-device verification, or integration with a production authentication service.
