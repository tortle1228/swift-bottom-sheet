import BottomSheetKit
import Observation
import SwiftUI
import WebKit

@Observable
final class SampleMessages {
  var message = "Injected environment"
}

private struct SampleCaptionKey: EnvironmentKey {
  static let defaultValue = "Missing caption"
}

extension EnvironmentValues {
  var sampleCaption: String {
    get { self[SampleCaptionKey.self] }
    set { self[SampleCaptionKey.self] = newValue }
  }
}

struct ContentSizedForm: View {
  @Environment(\.bottomSheetDismiss) private var dismiss
  @Environment(\.sampleCaption) private var caption
  @Environment(SampleMessages.self) private var messages
  @Binding var submitting: Bool
  let onContinue: () -> Void
  @State private var email = ""
  @State private var password = ""
  @State private var height: CGFloat = 0
  @State private var showsDetails = false
  @State private var showsModal = false
  @State private var showsError = false
  @FocusState private var focus: Field?

  private enum Field: Hashable { case email, password }

  var body: some View {
    scrollContent
      .bottomSheetContentHeight(height)
      .sheet(isPresented: $showsModal) {
        Button("Close system modal") { showsModal = false }
          .presentationDetents([.medium])
      }
      .task {
        if ProcessInfo.processInfo.arguments.contains("-focusForm") { focus = .email }
      }
  }

  @ViewBuilder
  private var scrollContent: some View {
    if #available(iOS 18, *) {
      formScroll.defaultScrollAnchor(focus == nil ? nil : .bottom, for: .sizeChanges)
    } else {
      formScroll
    }
  }

  private var formScroll: some View {
    ScrollView {
      VStack(spacing: 16) {
        Text("Content-sized form").font(.title2).accessibilityAddTraits(.isHeader)
        Text(caption).font(.caption)
        Text(messages.message).font(.caption)
        TextField("Email", text: $email)
          .textContentType(.emailAddress).textInputAutocapitalization(.never)
          .autocorrectionDisabled().keyboardType(.emailAddress)
          .focused($focus, equals: .email).submitLabel(.next)
          .onSubmit { focus = .password }
          .accessibilityIdentifier("formEmail")
        SecureField("Password", text: $password)
          .focused($focus, equals: .password).submitLabel(.go)
          .onSubmit(submit).accessibilityIdentifier("formPassword")
        if showsError {
          Text("The sample request failed. Your input is preserved; please try again.")
            .foregroundStyle(.red).accessibilityIdentifier("formError")
        }
        Button(submitting ? "Finish submission" : "Submit") {
          if submitting {
            submitting = false
            showsError = true
          } else {
            submit()
          }
        }
        Button(showsDetails ? "Hide details" : "Load details") {
          Task { @MainActor in
            await Task.yield()
            showsDetails.toggle()
          }
        }
        if showsDetails {
          ScrollView(.horizontal) {
            HStack {
              ForEach(0..<12) { index in
                Button("Choice \(index)") { messages.message = "Selected \(index)" }
                  .buttonStyle(.bordered)
              }
            }
          }
          SampleWebContent().frame(height: 180)
          ForEach(0..<12) { index in Text("Additional explanation \(index)") }
        }
        Button("Open system modal") { showsModal = true }
        Button("Continue after dismissal", action: onContinue)
        Button("Close form") { dismiss() }
      }
      .textFieldStyle(.roundedBorder)
      .padding(.horizontal, 20).padding(.bottom, 24)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        height = $0
      }
    }
    .scrollBounceBehavior(.basedOnSize)
    .scrollIndicatorsFlash(onAppear: true)
    .scrollDismissesKeyboard(.interactively)
  }

  private func submit() {
    focus = nil
    submitting = true
  }
}

private struct SampleWebContent: UIViewRepresentable {
  func makeUIView(context: Context) -> WKWebView {
    let view = WKWebView()
    view.loadHTMLString(
      "<meta name='viewport' content='width=device-width'><h2>Local web content</h2>"
        + String(repeating: "<p>Scrollable definition example.</p>", count: 12), baseURL: nil)
    return view
  }

  func updateUIView(_ view: WKWebView, context: Context) {}
}
