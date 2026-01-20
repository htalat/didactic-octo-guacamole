# Changelog

All notable changes to TodoMenuBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.2] - 2026-01-20

### Fixed
- Delete confirmation dialog no longer dismisses the entire app
- Replaced system `.alert()` with inline confirmation UI to prevent MenuBarExtra popup from losing focus

## [1.2.0] - 2025-07-29

### Added
- Clipboard-based data export - copy todos to clipboard as JSON
- Clipboard-based data import - paste todos directly from clipboard
- Visual confirmation when data is copied to clipboard

### Changed
- Replaced file dialog-based import/export with clipboard workflow
- Improved error messages to specify JSON format requirement
- Updated menu items to "Copy Data" and "Paste Data" for clarity

### Improved
- Much faster and more convenient data transfer workflow
- Better user experience without file system navigation

## [1.1.0] - 2025-07-29

### Added
- File-based import and export functionality
- Native macOS file dialogs for JSON files
- Success/failure feedback alerts for import/export operations

### Features
- Export preserves all todos and currently doing state
- Import validates JSON format and provides error feedback

## [1.0.0] - 2025-07-29

### Added
- Complete and Archive buttons for currently doing items
- Automatic lowercase conversion for all categories
- Category quick-select dropdown and buttons
- App version display in header

### Fixed
- Currently doing items now properly move to completed/archived status
- Category input experience with better suggestions
- Consistent category handling across the app

### Enhanced
- Smart category management with existing category suggestions
- Improved UI for category selection when adding/editing todos
- Better visual feedback for user actions

## [Initial] - 2025-07-29

### Added
- Initial TodoMenuBar macOS application
- Basic todo management (add, edit, delete, status changes)
- Category filtering and search functionality
- Currently doing item tracking
- Persistent storage using UserDefaults
- SwiftUI-based interface optimized for menu bar usage