# TodoMenuBar

A clean and efficient macOS menubar todo application built with SwiftUI.

## Features

- **Menu Bar Integration**: Lives in your system menubar for quick access
- **Three-Tab Organization**: In-Progress, Completed, and Archived todos
- **Rich Todo Details**: Title, description, and category for each todo
- **Currently Doing**: Special section to highlight your active task
- **Smart Search**: Search across title, description, and category
- **Category Filtering**: Filter todos by category with dynamic filter chips
- **Full CRUD Operations**: Create, edit, delete todos with confirmation dialogs
- **Persistent Storage**: Local todos are saved automatically in SQLite
- **Multiple Data Sources**: Shows todos from local storage and from [Timmu](#timmu); more sources can be added

## Installation

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/htalat/didactic-octo-guacamole.git
cd didactic-octo-guacamole
```

2. Build and run:
```bash
swift run
```

### Requirements

- macOS 14.0 or later
- Swift 5.9 or later

## Usage

1. **Launch**: Run the app and look for the checkmark icon in your menubar
2. **Add Todos**: Click "+ Add Todo" to create new todos with title, description, and category
3. **Organize**: Use the three tabs to organize todos by status
4. **Current Focus**: Set any todo as "currently doing" for quick reference
5. **Search & Filter**: Use the search bar and category filters to find specific todos
6. **Edit**: Double-tap any todo title or use the edit button to modify
7. **Delete**: Click the red trash icon or use the context menu (with confirmation)

## Data sources

Todos come from one or more *sources*. `TodoStore` merges the todos of all sources and sends each change to the source that owns the todo. Each todo has a `sourceID`.

| Source | What it shows | Capabilities |
| --- | --- | --- |
| Local | Todos kept in SQLite on this Mac | create, edit, delete, archive |
| Timmu | The Timmu inbox (activities with no `startAt`) | create, edit, delete |

### Timmu

1. Start the Timmu backend (default `http://localhost:3000`).
2. In the app, open the `…` menu and click **Sources…**.
3. Type the server URL, email, and password, then click **Connect**.

The app does not store the password. It keeps the sign-in token in the Keychain. Timmu priorities (`high`, `medium`, `low`) show as categories; set one of these categories to set the priority. Timmu has no archive, so the app hides "Archive" for Timmu todos.

### Add a new source

1. Make a type that conforms to `TodoSource` (`Sources/Shared/TodoSource.swift`): `fetchTodos`, `create`, `update`, `delete`, and `capabilities`.
2. Add it in `TodoSourceFactory.makeSources()` (`Sources/Shared/SourceSettings.swift`).

The UI uses `capabilities` to show or hide actions for each todo.

## Development

### Running Tests

```bash
swift test
```

To also run the Timmu integration test against a running Timmu server (it makes a throwaway account):

```bash
TIMMU_TEST_URL=http://localhost:3000 swift test
```

### Project Structure

- `Sources/TodoApp/App.swift` - App entry point and menubar setup
- `Sources/Shared/TodoModel.swift` - Data models and local storage (SQLite, UserDefaults)
- `Sources/Shared/TodoStore.swift` - Merges all sources and sends changes to them
- `Sources/Shared/TodoSource.swift` - `TodoSource` protocol and the local source
- `Sources/Shared/TimmuTodoSource.swift` - Timmu API client and source
- `Sources/Shared/SourceSettings.swift` - Source factory, Timmu settings, Keychain
- `Sources/Shared/ContentView.swift`, `SourcesSettingsView.swift` - SwiftUI interface
- `Tests/TodoMenuBarTests/` - Test suite

## License

This project is available under the MIT License.