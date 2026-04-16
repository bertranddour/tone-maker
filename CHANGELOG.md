# Changelog

All notable changes to ToneMaker are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-04-16

### Added

- **Profile Studio** -- full NAM training workflow
  - Audio drop zones with drag-and-drop and WAV validation
  - Inline metadata editor (rig name, brand, model, gear type, gain)
  - Training parameter configuration with presets
  - Advanced options (learning rate, batch size, MRSTFT, latency override, ESR threshold)
  - Real-time training dashboard with epoch progress, ESR display, and log streaming
  - Automatic capture import to library on training completion
  - Batch training for multiple output files

- **Capture Library** -- browse, manage, and export trained models
  - Color-coded grid by gain type (Clean, Overdrive, Crunch, High Gain, Fuzz)
  - Sidebar navigation with gear type categories and brand grouping
  - Sectioned grid with sticky Brand + Model headers
  - Full-text search across rig name, brand, model, and gain type
  - Inspector pane with editable metadata and .nam file export
  - Import .nam files with automatic JSON metadata extraction
  - Multi-select with Cmd+click for bulk delete
  - PED/CAB indicators for chain configurations

- **Training Engine**
  - Python bridge to NAM Trainer via ProcessRunner with real-time output streaming
  - Custom PyTorch Lightning callback for epoch progress
  - Output parser for structured training events (ESR, latency, warnings, export paths)
  - Temp directory training with automatic cleanup after capture import

- **Data Persistence**
  - SwiftData models with CloudKit sync support
  - `@Attribute(.externalStorage)` for audio files and .nam model data
  - Security-scoped bookmarks with persisted audio fallback
  - Lightweight migration (additive schema, no migration plan needed)

- **Settings**
  - NAM-Trainer project path configuration
  - Python environment auto-detection and validation
  - Default training parameters (epochs, architecture, size)
  - Metadata defaults (modeled by, calibration levels)

- **Testing** -- 129 tests using Swift Testing
  - Model tests (TrainingSession, ModelMetadata, CaptureItem, PersistedAudioFile)
  - Service tests (TrainingEngine, OutputParser, ProcessRunner, InputValidator, ArgumentBuilder)
  - Utility tests (Defaults/ESRQuality, FileBookmark, WAVHeaderReader)
