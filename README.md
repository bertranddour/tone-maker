# ToneMaker

A native macOS application for training and managing [Neural Amp Modeler (NAM)](https://github.com/sdatkinson/neural-amp-modeler) guitar amp captures. Built with SwiftUI, SwiftData, and Liquid Glass for macOS 26.

ToneMaker replaces the Python/Tkinter NAM Trainer GUI with a production-grade Mac experience: real-time training visualization, a color-coded capture library with CloudKit sync, and full metadata management.

## Features

### Profile Studio

- **Audio drop zones** for reference and reamped audio files with drag-and-drop and file validation
- **Inline metadata editor** -- rig name, brand, model, gear type, and gain classification
- **Full NAM parameter control** -- epochs, learning rate, batch size, architecture (WaveNet/LSTM), size (Standard/Lite/Feather/Nano), and all advanced options
- **Real-time training dashboard** with epoch progress, live ESR display, animated status indicators, and streaming log output
- **Automatic capture import** -- trained models are imported directly into the library; no output folder needed
- **Batch training** -- train multiple output files sequentially
- **Preset system** -- save and load training configurations

### Capture Library

- **Color-coded grid** sorted by gain type: cyan (Clean), yellow (Overdrive), orange (Crunch), red (High Gain), purple (Fuzz)
- **Sidebar navigation** with gear type categories and brand grouping
- **Sectioned grid** with sticky Brand + Model headers
- **Search** across rig name, brand, model, and gain type
- **Inspector pane** with editable metadata and `.nam` file export
- **Import `.nam` files** with automatic JSON metadata extraction
- **Multi-select** with Cmd+click for bulk delete
- **PED/CAB indicators** on thumbnails for chain configurations

### Infrastructure

- **CloudKit sync** via SwiftData with `@Attribute(.externalStorage)` for audio and model files
- **Security-scoped bookmarks** with persisted audio fallback for session recovery
- **Zero external dependencies** -- uses only Apple frameworks
- **129 tests** across models, services, and utilities using Swift Testing

## Requirements

- macOS 26 or later
- Apple Silicon (MPS acceleration) or Intel (CPU training)
- [NAM-Trainer](https://github.com/sdatkinson/neural-amp-modeler) project with Python venv

## Setup

### 1. Clone

```bash
git clone git@github.com:bertranddour/tone-maker.git
cd tone-maker
```

### 2. Open in Xcode

```bash
open ToneMaker.xcodeproj
```

### 3. Configure NAM-Trainer

ToneMaker shells out to the NAM-Trainer Python project for training. Set the project path in **Settings > General > NAM-Trainer Project**.

Default search locations:
- `~/Developer/NAM-Trainer`
- `~/Projects/NAM-Trainer`
- `~/Code/NAM-Trainer`
- `~/NAM-Trainer`

The project must have a `.venv/bin/python3` with the `nam` package installed.

### 4. Build and Run

Select the ToneMaker scheme and run (Cmd+R). Training requires disabling Metal API Validation in the scheme diagnostics (PyTorch MPS debug assertions).

## Architecture

```
ToneMaker/
  Models/           SwiftData @Model entities + enums
  Services/         Training engine, Python bridge, file validation
  Utilities/        Defaults, bookmarks, WAV reader
  Views/
    Detail/         Training config, dashboard, library grid, inspector
    Settings/       App preferences
    Shared/         Reusable components (drop zones, badges, cells)
```

### Data Flow

```
TrainingConfigView --> TrainingEngine --> NAMTrainerService --> ProcessRunner
                                    |                              |
                              @Observable                    Python bridge
                              live state                    (nam.train.core)
                                    |                              |
                         TrainingDashboardView <-- OutputParser <-- stdout
                                    |
                              CaptureItem (library)
```

### Key Patterns

- **No ViewModels** -- views bind directly to `@Model` objects via `@Bindable` and `@Query` (WWDC SwiftData pattern)
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** -- all pure value types marked `nonisolated`
- **Actor isolation** for services (`NAMTrainerService`, `ProcessRunner`)
- **`@Attribute(.externalStorage)`** for binary data (audio files, .nam models) -- maps to CKAssets with CloudKit
- **Raw-value backed enums** with computed typed accessors for CloudKit compatibility

## License

[Apache License 2.0](LICENSE)
