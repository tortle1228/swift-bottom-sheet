import BottomSheetKit
import SwiftUI

@main
struct SampleApp: App {
  var body: some Scene {
    WindowGroup {
      SampleView()
    }
  }
}

private struct SampleItem: Identifiable {
  var id: Int
  var revision = 0
}

private struct SampleView: View {
  @Environment(\.dynamicTypeSize) private var textSize
  @State private var presented = ProcessInfo.processInfo.arguments.contains("-showInput")
  @State private var item: SampleItem?
  @State private var dismissals = 0
  @State private var longContent = false
  @State private var ownScroll = false
  @State private var showsForm = ProcessInfo.processInfo.arguments.contains("-showForm")
  @State private var submitting = false
  @State private var followup = false
  @State private var followupRequested = false
  @State private var messages = SampleMessages()
  private let id = BottomSheetID("sample")

  var body: some View {
    VStack(spacing: 24) {
      Text("BottomSheetKit").font(.title)
      Text("Dismissals: \(dismissals)").accessibilityIdentifier("dismissals")
      Button("Show input") {
        longContent = false
        ownScroll = false
        presented = true
      }
      Button("Show long content") {
        longContent = true
        ownScroll = false
        presented = true
      }
      Button("Show list") {
        ownScroll = true
        presented = true
      }
      Button("Show item") { item = SampleItem(id: 1) }
      Button("Show form") { showsForm = true }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.secondarySystemBackground))
    .bottomSheet(
      isPresented: $presented, id: id, configuration: configuration,
      onDismiss: { dismissals += 1 }
    ) {
      if ownScroll {
        List(0..<100, id: \.self) { Text("Row \($0)") }
      } else {
        InputContent(
          longContent: longContent,
          closeBinding: { presented = false },
          closeGlobal: {
            BottomSheetPresenter.shared.dismiss(id: id)
            BottomSheetPresenter.shared.dismiss(id: id)
          })
      }
    }
    .bottomSheet(item: $item, onDismiss: { dismissals += 1 }) { value in
      ItemContent(
        value: value, update: { item?.revision += 1 },
        replace: { item = SampleItem(id: value.id + 1) }, clear: { item = nil })
    }
    .bottomSheet(
      isPresented: $showsForm, configuration: formConfiguration,
      onDismiss: {
        dismissals += 1
        submitting = false
        followup = followupRequested
        followupRequested = false
      }
    ) {
      ContentSizedForm(submitting: $submitting) {
        followupRequested = true
        showsForm = false
      }
      .environment(messages)
      .environment(\.sampleCaption, "Explicit custom environment")
      .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
    .sheet(isPresented: $followup) {
      Button("Follow-up complete") { followup = false }
    }
    .dynamicTypeSize(
      ProcessInfo.processInfo.arguments.contains("-accessibilityText") ? .accessibility5 : textSize)
  }

  private var configuration: BottomSheetConfiguration {
    var value = BottomSheetConfiguration()
    value.contentScrolling = ownScroll ? .content : .automatic
    return value
  }

  private var formConfiguration: BottomSheetConfiguration {
    var value = BottomSheetConfiguration()
    value.maximumWidth = 600
    value.contentScrolling = .content
    value.contentInsets = EdgeInsets()
    value.dismissesOnBackdropTap = !submitting
    value.dismissesOnDrag = !submitting
    return value
  }
}

private struct ItemContent: View {
  let value: SampleItem
  let update: () -> Void
  let replace: () -> Void
  let clear: () -> Void
  @State private var draft = ""

  var body: some View {
    VStack(spacing: 20) {
      Text("Item \(value.id)")
      Text("Revision \(value.revision)")
      TextField("Draft", text: $draft).accessibilityIdentifier("itemDraft")
      Button("Update item", action: update)
      Button("Replace item", action: replace)
      Button("Clear item", action: clear)
    }
  }
}

private struct InputContent: View {
  @Environment(\.bottomSheetDismiss) private var dismiss
  @State private var text = ""
  let longContent: Bool
  let closeBinding: () -> Void
  let closeGlobal: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Text("Sign in").font(.title2).accessibilityAddTraits(.isHeader)
      TextField("Email", text: $text).textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(
        .emailAddress
      )
      .accessibilityIdentifier("email")
      Button("Environment close") { dismiss() }
      Button("Binding close", action: closeBinding)
      Button("Global close", action: closeGlobal)
      if longContent {
        ForEach(0..<40, id: \.self) { Text("Content row \($0)").frame(maxWidth: .infinity) }
        Button("End close") { dismiss() }
      }
    }
  }
}
