# Working Rules

- Support iOS 17 and later, Swift tools 6.0, and Swift 6 language mode.
- Keep one library module, BottomSheetKit. Put tests in Tests/BottomSheetKitTests
  and runnable usage examples in Examples. Do not edit the reference apps.
- Keep public APIs small. Do not add runtime dependencies, global presentation,
  popup stacks, or private platform APIs.
- Isolate UI and dismissal registration to MainActor. Presentation bindings own
  state; the global presenter only holds weak dismissal targets.
- Preserve keyboard avoidance, safe-area accounting, content scrolling,
  VoiceOver focus, Dynamic Type, and Reduce Motion when changing layout.
- Use Context7 for framework, library, SDK, API, and CLI questions. Resolve the
  library ID first, then query the relevant concept. Prefer official sources.

## Commands

- Run scripts/bootstrap once per clone to verify tools and enable local hooks.
- Run scripts/format to format source explicitly.
- Run scripts/lint for formatting and SwiftLint checks.
- Run scripts/check for lint, hook self-checks, package tests, and sample UI tests.
  Set SIMULATOR_ID to select a simulator; otherwise the first available iPhone is used.
- Run python3 scripts/test-hooks to check hooks independently.
- The sample Xcode project is checked in. After editing Examples/project.yml,
  regenerate it with xcodegen generate --spec Examples/project.yml.
- Use SwiftLint 0.65.1. CI pins Xcode; local checks use the selected Xcode's
  swift-format. Resolve format differences with the CI toolchain before merging.

## Documentation

- Write development instructions and source comments in English.
- Maintain README.md in English and README.ko.md in Korean. Keep their examples,
  requirements, supported behavior, and limitations synchronized; link them to each other.
- Apart from these two READMEs, do not create standalone documentation, design notes,
  ADRs, roadmaps, changelogs, or DocC catalogs.
- Document every public API with a concise triple-slash summary. Explain defaults,
  units, side effects, lifecycle behavior, and constraints that affect callers.
- Add parameter, return-value, and error descriptions when they clarify usage.
- Internal comments explain non-obvious rationale and invariants, not syntax.
- Keep executable examples in the sample app and behavioral guarantees in tests.
  Update comments and tests with behavior changes. Record change rationale in commits.
- Never copy credentials, product assets, or application source into this package.

## Commits and Checks

- Write commit subjects and bodies in English using Conventional Commits:
  type(scope): Description. Scope is optional; use ! for breaking changes.
- Allowed types: feat, fix, refactor, chore, test, docs, style, build, ci, perf, revert.
  Keep subjects concise and omit the trailing period.
- Hooks check staged snapshots and never download, rewrite, or stage files.
- Do not bypass hooks. Run the full check before pushing; CI repeats validation.
- Add focused tests for non-trivial behavior, especially transitions, repeated
  dismissal, identifier ownership, keyboard layout, and size changes.
- Report deployment-target compilation separately from runtime verification.
