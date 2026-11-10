# BottomSheetKit

[English](README.md) | [한국어](README.ko.md)

폼, 선택 목록, 설명처럼 콘텐츠에 맞는 높이가 필요한 화면을 위한 SwiftUI 바텀 시트입니다. UIKit 커스텀 프레젠테이션을 사용하며, 화면 하단에 붙은 키보드 위로 이동하고 가용 높이를 넘는 콘텐츠는 스크롤로 보여줍니다.

## 요구사항과 설치

- iOS 17 이상, Swift tools 6.0 및 Swift 6 언어 모드.
- iOS SDK와 Swift 6을 지원하는 Xcode. 아래 높이 측정 예제는 Xcode 16 이상에서 제공하는 단일 값 `onGeometryChange` API를 사용합니다.
- 라이브러리 제품명과 import 이름은 `BottomSheetKit`입니다. 런타임 패키지 의존성은 없습니다.

앱의 Xcode 프로젝트에서 **File → Add Package Dependencies**를 선택하고 `https://github.com/tortle1228/swift-bottom-sheet.git`을 입력하세요. **main** 브랜치를 선택한 뒤 **BottomSheetKit** 제품을 앱 타깃에 추가하세요. [저장소](https://github.com/tortle1228/swift-bottom-sheet)는 공개되어 있으며 현재 버전 태그는 없습니다. 브랜치 의존성은 버전이 고정된 릴리스가 아니라 계속 변경되는 코드를 따릅니다.

로컬 개발 시에는 **Add Local**을 선택하고, `Package.swift`가 있는 이 저장소 폴더를 지정한 뒤 **BottomSheetKit**을 앱 타깃에 추가하세요.

Apple의 [로컬 패키지 추가 안내](https://developer.apple.com/documentation/xcode/editing-a-package-dependency-as-a-local-package)와 [원격 패키지 설치 안내](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)를 참고할 수 있습니다.

## 시트 표시와 닫기

앱의 뷰 계층에 `SheetExample()`을 넣으세요. Show sheet를 누르면 콘텐츠가 나타나고, Close를 누르면 시트가 닫히면서 바인딩이 `false`로 바뀝니다.

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

표시 상태는 바인딩이 소유합니다. 바인딩을 직접 `false`로 설정해 닫을 수도 있습니다. modifier는 수명이 안정적인 뷰에 붙이세요. 시트 내부에서 사용하는 환경 액션은 시스템 시트의 `dismiss`가 아닌 `bottomSheetDismiss`입니다.

## 항목 기반 표시와 닫기 생명주기

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

같은 ID의 항목을 갱신하면 콘텐츠를 제자리에서 업데이트하며 내부 SwiftUI 상태를 유지합니다. ID가 바뀌면 기존 시트를 닫은 뒤 새 시트를 표시하고, 새 콘텐츠의 내부 상태는 초기화됩니다. 이전 항목을 닫는 과정이 다른 ID를 가진 새 항목을 지우지는 않습니다.

`onDismiss`는 닫기 전환이 끝난 뒤 완료된 닫기마다 한 번 호출됩니다. 바인딩은 닫기를 요청할 때 초기화됩니다. 후속 화면은 `onDismiss`에서 표시하세요. 항목 교체도 기존 시트의 닫기를 완료합니다.

콘텐츠 계층 밖에서 닫으려면 두 modifier 중 하나에 `id: BottomSheetID("account")`를 전달하고, 메인 액터에서 `BottomSheetPresenter.shared.dismiss(id: BottomSheetID("account"))`를 호출하세요. 이 레지스트리는 닫기만 담당하며 시트를 표시하지 않습니다. 여러 창을 포함해 동시에 표시된 시트의 ID는 고유해야 합니다. 활성 ID가 중복되면 새 표시를 거부하고 해당 바인딩을 초기화합니다. 등록되지 않은 ID나 중복 닫기 요청은 아무 동작도 하지 않습니다.

## 높이, 너비와 스크롤

시트는 콘텐츠 높이에 맞춰지며, 상단 안전 영역 아래 12pt부터 화면 하단 또는 화면 하단에 붙은 키보드 상단까지의 공간을 넘지 않습니다. 공개 최대 높이 설정이나 detent 설정은 없습니다. 키보드가 없으면 하단 안전 영역을 한 번 추가합니다.

- `.automatic`(기본값)은 일반 콘텐츠를 UIKit 스크롤 뷰로 감쌉니다. 높이를 넘으면 시트 안에서 스크롤됩니다. 이 모드에는 자체 세로 스크롤 뷰를 중첩하지 마세요.
- `.content`는 `ScrollView`나 `List` 등 콘텐츠가 스크롤을 담당합니다. 높이를 보고하지 않으면 가용 높이를 채웁니다.
- `.content`에서는 시트 콘텐츠에 `bottomSheetContentHeight(_:)`를 한 번 붙여 자연 높이를 전달합니다. 스크롤 표시 영역이 아니라 **내부 콘텐츠와 그 자체 패딩**을 측정하세요. 패키지는 설정된 콘텐츠 패딩, 그랩버 공간, 하단 안전 영역을 추가합니다. 아래 예제는 자체 패딩을 사용하므로 패키지 패딩을 0으로 설정합니다.
- nil, 0 이하, 유한하지 않은 높이는 가용 높이를 채우는 동작으로 돌아갑니다. `.automatic`은 보고된 높이를 무시합니다. 높이가 바뀌면 기존 콘텐츠의 크기를 조절하며, 큰 콘텐츠에는 여전히 자체 스크롤이 필요합니다.

`maximumWidth`의 기본값은 nil이며 수평 안전 영역의 가용 너비를 사용합니다. 양의 유한한 값은 너비를 제한하고 시트를 중앙에 놓습니다. 가용 너비보다 큰 값은 제한되며, 0 이하나 유한하지 않은 값은 무시합니다. 기본 iPad 고정 너비는 없습니다.

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

이 예제는 전체 콘텐츠 높이를 알 수 있도록 일반 `VStack`을 사용합니다. 큰 지연 로딩 목록은 `.content`의 전체 높이 동작을 유지하거나, 생성된 행만 측정하는 대신 데이터로 계산한 높이를 전달하세요.

## 설정과 통합 시 주의사항

`BottomSheetConfiguration`을 만들고 속성을 설정한 뒤 `configuration:`으로 전달하세요. 크기 단위는 pt입니다.

| 속성 | 기본값 |
| --- | --- |
| `maximumWidth` | `nil`(가용 너비) |
| `cornerRadius` | `32`, 상단 모서리 |
| `backgroundColor` | 시스템 배경색; 하단에 붙은 키보드 모서리 뒤까지 연장 |
| `showsGrabber` | `true` |
| `grabberSize` / `grabberColor` | `40 × 5` / 보조 시스템 회색 |
| `grabberInsets` | 상단 `8`, 하단 `20`, leading/trailing `0` |
| `contentInsets` | 상단 `0`, leading/trailing `20`, 하단 `32` |
| `dimmingColor` / `dimmingOpacity` | 검정 / `0.5`; 불투명도는 `0...1`로 제한 |
| `dismissesOnBackdropTap` / `dismissesOnDrag` | `true` / `true` |
| `contentScrolling` | `.automatic` |

제출 중 두 닫기 플래그를 모두 `false`로 설정하면 배경 탭, 그랩버 드래그, 접근성 escape로 닫히지 않습니다. 바인딩·환경 액션·ID를 통한 명시적 닫기는 계속 가능합니다. 드래그 닫기는 그랩버에서 시작하며, 높이 단계를 전환하는 detent 동작은 아닙니다.

글씨 크기, 색상 모드, 로케일, 레이아웃 방향은 표시하는 뷰에서 상속합니다. 그 밖의 환경 값과 객체는 **시트 콘텐츠 클로저 안에서** 명시적으로 주입하세요. [폼 샘플](Examples/Sample/ContentSizedForm.swift)과 [표시하는 코드](Examples/Sample/SampleApp.swift)에 관찰 가능한 환경 객체 주입, 포커스, 키보드 처리, 동적 높이, 제출 잠금, 중첩 시스템 모달 예제가 있습니다.

Dynamic Type, VoiceOver 모달 포커스와 escape, Reduce Motion을 지원합니다. 큰 글씨에서도 콘텐츠의 접근성과 스크롤 가능 여부를 유지하세요. 전역 표시, 팝업 스택, SwiftUI 시스템 시트 detent는 제공하지 않습니다. 키보드 회피는 화면 하단에 붙은 키보드를 따르며, 플로팅 키보드의 겹침을 자동으로 피하지 않습니다.

## 샘플 실행과 기여

[Examples/BottomSheetSample.xcodeproj](Examples/BottomSheetSample.xcodeproj)를 열고 **BottomSheetSample** 스킴과 iOS 시뮬레이터를 선택해 실행하세요. 저장된 프로젝트는 서명이 비활성화되어 있습니다. 스킴의 Run 동작에서 다음 실행 인자를 사용할 수 있습니다.

| 인자 | 동작 |
| --- | --- |
| `-showInput` | 기본 입력 시트 표시 |
| `-showForm` | 콘텐츠 높이에 맞는 폼 표시(최대 너비 600pt) |
| `-focusForm` | 폼 이메일 필드에 포커스; `-showForm`과 함께 사용 |
| `-accessibilityText` | 접근성 최대 글씨 요청; 폼 콘텐츠는 의도적으로 `accessibility1`까지 제한 |

저장소 개발 시 SwiftLint **0.65.1**을 설치하고 `swift-format`이 포함된 Xcode 도구 체인을 선택하세요. 저장소 루트에서 실행합니다.

```sh
scripts/bootstrap
scripts/lint
scripts/check
```

Bootstrap은 이 저장소의 로컬 Git 훅을 활성화합니다. `scripts/check`는 린트, 훅 자체 검사, 패키지 테스트, 샘플 UI 테스트를 실행합니다. `SIMULATOR_ID`를 지정하지 않으면 첫 번째 사용 가능한 iPhone 시뮬레이터를 선택합니다. 소스 포맷은 `scripts/format`으로 명시적으로 실행하세요. UIKit 패키지 테스트에는 iOS 시뮬레이터가 필요하며 macOS의 `swift test`는 테스트 진입점이 아닙니다. XcodeGen은 `Examples/project.yml` 수정 후 프로젝트를 재생성할 때만 필요하고, 저장된 프로젝트를 여는 데는 필요하지 않습니다. [작업 규칙](AGENTS.md)과 [CI 워크플로](.github/workflows/check.yml)를 참고하세요.

`87a8704` 구현은 린트·훅 검사, 단위 테스트 16개, UI 테스트 11개와 추가 작은 iPhone·iPad 레이아웃 검사를 통과했습니다. iOS 17 배포 타깃·Swift 6 모드로 컴파일했으며 런타임 검사는 iOS 27.2 시뮬레이터에서 수행했습니다. 이는 iOS 17 런타임·실기기 검증이나 실제 인증 서비스 통합 검증을 의미하지 않습니다.

## 라이선스

[MIT 라이선스](LICENSE)를 적용합니다. Copyright (c) 2026 Jaehoon Lee.
