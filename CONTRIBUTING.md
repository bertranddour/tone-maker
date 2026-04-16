# Contributing to ToneMaker

Thank you for your interest in contributing to ToneMaker. This document outlines the process and standards for contributions.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Open `ToneMaker.xcodeproj` in Xcode
4. Create a feature branch from `main`

## Development Requirements

- macOS 26 or later
- Xcode 26 or later
- Apple Silicon Mac (recommended for MPS testing)
- NAM-Trainer project with Python venv (for training features)

## Code Standards

Read [CLAUDE.md](CLAUDE.md) for the full coding guidelines. The key points:

### Zero Tolerance

Every PR must:
- Build with **zero warnings** and zero errors
- Pass all **129+ tests**
- Follow the existing SwiftUI/SwiftData patterns
- Use Apple official documentation as the source of truth

### Architecture

- **No ViewModels** -- bind directly to `@Model` objects via `@Bindable` and `@Query`
- **No external dependencies** -- Apple frameworks only
- **`nonisolated`** on all pure value types (project uses `MainActor` default isolation)
- **CloudKit-compatible** `@Model` classes (default values, optional relationships, no unique constraints)

### Style

- Swift Testing (`@Test`) for all tests
- `os.log` Logger for all logging (no `print()`)
- One type per file
- SF Symbols for icons

## Pull Request Process

### Before Submitting

1. **Build** -- zero warnings, zero errors
2. **Test** -- all tests pass (`Cmd+U` or `mcp__xcode__RunAllTests`)
3. **Verify visually** -- run the app and check your changes
4. **Check CloudKit compatibility** -- new `@Model` properties need defaults

### PR Guidelines

- Keep PRs focused on a single feature or fix
- Write a clear description of what changed and why
- Reference any related issues
- Include test coverage for new logic

### Commit Messages

Use a concise summary line followed by details:

```
Add batch export for library captures

Export multiple selected captures as .nam files in a single operation.
Uses NSSavePanel with directory selection for the export destination.
```

## Reporting Issues

- Use GitHub Issues
- Include macOS version, steps to reproduce, and expected vs actual behavior
- For training issues, include the Python/NAM version and training log output

## Areas for Contribution

- Additional NAM model format support
- Capture comparison tooling
- Audio preview/playback
- Drag-and-drop to external apps (amp modeler plugins)
- Localization
- Accessibility improvements

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
