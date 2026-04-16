# CLAUDE.md -- AI Assistant Guidelines for ToneMaker

This file defines the coding standards, workflow, and constraints for AI assistants (Claude Code, Copilot, etc.) contributing to ToneMaker.

## Documentation First

**Always query Apple official documentation before writing code.**

Use the Xcode MCP `DocumentationSearch` tool for every SwiftUI, SwiftData, and framework API decision. Do not rely on general knowledge -- Apple APIs change between OS versions. ToneMaker targets macOS 26, which may have newer patterns than training data reflects.

```
mcp__xcode__DocumentationSearch(query: "NavigationSplitView sidebar selection", frameworks: ["SwiftUI"])
```

## Build Standards

### Zero Tolerance Policy

- **Zero warnings.** Every build must produce zero compiler warnings. No suppressions, no `@available` workarounds for things that should just be fixed.
- **Zero errors.** Obviously.
- **All tests pass.** Run `mcp__xcode__RunAllTests` after every change.
- **No regressions.** Don't break existing features when adding new ones.

### Build Verification

After every code change:
1. `mcp__xcode__BuildProject` -- must succeed with zero errors
2. `mcp__xcode__RunAllTests` -- 129/129 must pass
3. Check for new warnings in build output

## Swift & SwiftUI Patterns

### macOS 26 + Swift 6

- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** -- the project uses MainActor as the default isolation context
- Mark ALL pure value types (enums, structs not tied to UI) as `nonisolated`
- Use `nonisolated let` for file-level constants (e.g., Logger instances)
- Actors for services: `NAMTrainerService`, `ProcessRunner`

### SwiftData (No ViewModels)

Follow the WWDC SwiftData pattern -- views bind directly to model objects:

```swift
// Correct: direct @Bindable binding
@Bindable var session: TrainingSession
TextField("Name", text: $session.name)

// Correct: @Query in views
@Query(sort: \TrainingSession.createdAt) private var sessions: [TrainingSession]

// Wrong: intermediate ViewModel layer
class SessionViewModel: ObservableObject { ... }  // Don't do this
```

### CloudKit Compatibility

All `@Model` classes must be CloudKit-compatible:
- **No `@Attribute(.unique)`** -- CloudKit cannot enforce unique constraints
- **All properties have default values** or are optional
- **All relationships are optional** (including to-many: `[T]?`)
- **No `.deny` delete rules**
- Use `@Attribute(.externalStorage)` for binary data (becomes CKAssets)

### Enum Pattern

All model enums follow the raw-value-backed pattern for SwiftData/CloudKit:

```swift
// In the @Model class:
var gearTypeRaw: String?

// Computed accessor in extension:
var gearType: GearType? {
    get { gearTypeRaw.flatMap { GearType(rawValue: $0) } }
    set { gearTypeRaw = newValue?.rawValue }
}
```

### UI Patterns

- **Segmented pickers** for 2-5 options (per Apple HIG)
- **Dropdown/menu pickers** for 5+ options
- **`.inspector(isPresented:content:)`** for detail panes
- **`LazyVGrid` with `GridItem(.adaptive(minimum:))`** for grids
- **`.searchable(text:prompt:)`** for search
- **`.confirmationDialog`** before destructive actions
- **`@FocusState` + `RenameButton()` + `.renameAction`** for inline rename
- **`.symbolEffect(.breathe)`** for animated status indicators

## Logging

Use Apple's `os.log` framework with structured Logger instances:

```swift
private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "CategoryName")
```

- `logger.info()` for successful operations and key state changes
- `logger.debug()` for detailed diagnostic information
- `logger.warning()` for recoverable issues
- `logger.error()` for failures that prevent an operation
- Never use `print()` -- always Logger

## Testing

- Use **Swift Testing** (`@Test` macros), not XCTest
- Test file naming: `{ClassName}Tests.swift` in the matching directory structure
- Test all enum raw value round-trips
- Test all computed properties
- Test edge cases (nil, empty, boundary values)
- Integration tests for services use real file I/O where practical

## Architecture Rules

- **DRY** -- extract shared logic. Don't duplicate color mappings, enum display names, or validation logic.
- **No speculative abstractions** -- don't add layers for hypothetical future needs
- **No external dependencies** -- Apple frameworks only
- **File per type** -- each model, enum, view, and service gets its own file
- **Enums in `Models/Enums/`** -- all model-layer enums live here
- **Shared views in `Views/Shared/`** -- reusable UI components

## Code Style

- No trailing summaries ("Here's what I did...") -- the diff speaks for itself
- No comments unless the logic isn't self-evident
- No docstrings on properties that are self-documenting
- Docstrings on public types and non-obvious functions use `///` with a single sentence
- Use SF Symbols for icons (check availability for macOS 26)
- `nonisolated` goes before access control: `nonisolated enum`, `private nonisolated let`

## NAM-Specific Context

- The Python NAM Trainer lives at the user-configured path (default: `~/Developer/NAM-Trainer`)
- Training uses `.venv/bin/python3` directly (not `uv run`)
- `.nam` files are JSON format (modern NAM) with metadata under the `"metadata"` key
- ESR quality thresholds come from `nam.train.core` (0.01, 0.035, 0.1, 0.3)
- The Python bridge monkey-patches PyTorch Lightning's Trainer to inject a progress callback
- `matplotlib.use("Agg")` is required to prevent `plt.show()` from blocking
- `PYTHONUNBUFFERED=1` is required for real-time log streaming
