# CPA Visualize Widget

CPA Visualize Widget is a macOS SwiftUI app and WidgetKit extension for monitoring Usage Keeper statistics from the desktop. The host app stores the Usage Keeper connection settings, periodically syncs usage snapshots, and shares them with the desktop widget through an App Group.

## Features

- Desktop widgets for quick CPA/Usage Keeper monitoring.
- Today summary for total tokens, cached tokens, reasoning tokens, and cost.
- Hourly token trend chart with a dark snow-night aurora style.
- Usage Keeper password-login support with session storage in Keychain.
- Shared snapshot storage through App Groups for the Widget extension.
- Automatic sync every 5 minutes in the host app; WidgetKit refreshes from the shared snapshot.

## Project structure

```text
CPAVisualizeApp/      Host macOS app, settings UI, sync logic, storage
CPAWidgetExtension/   WidgetKit extension and widget SwiftUI views
Shared/               Shared models and constants
scripts/              Local rebuild/install helper scripts
```

## Requirements

- macOS with Xcode installed.
- A running Usage Keeper service.
- App Group entitlement configured as `group.com.xiongkaiwen.CPAVisualize`.

## Usage

1. Open `CPAVisualize.xcodeproj` in Xcode.
2. Build and run the `CPAVisualize` scheme.
3. Enter the Usage Keeper URL in the host app.
4. Enable password login if your Usage Keeper instance requires it.
5. Save settings and wait for the shared snapshot to sync.
6. Add the `CPA Usage` widget to the desktop.

## Local rebuild and install

This repository includes a helper script that cleans app/widget runtime caches, rebuilds the Debug app, installs it into `/Applications`, and relaunches it:

```bash
./scripts/rebuild-and-install.sh
```

The script intentionally keeps UserDefaults and Keychain values while clearing build products and widget runtime caches.

## Notes

Generated build products, local tooling directories, DMG artifacts, and unrelated scratch projects are ignored by `.gitignore` and are not part of the repository.
