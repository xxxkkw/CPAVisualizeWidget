# CPA Visualize Widget

[中文](README.zh-CN.md) | English

CPA Visualize Widget is a macOS SwiftUI app and WidgetKit extension for monitoring Usage Keeper statistics from the desktop. The host app stores Usage Keeper connection settings, periodically syncs usage snapshots, and shares them with the desktop widget through an App Group.

<p align="center">
  <img src="img.png" alt="CPA Visualize Widget preview" width="520">
</p>

## Features

- Desktop widget for quick CPA/Usage Keeper monitoring.
- Today summary for total tokens, cached tokens, reasoning tokens, and cost.
- Usage Keeper password-login support with session storage in Keychain.
- Shared snapshot storage through App Groups for the Widget extension.
- Automatic sync every 5 minutes in the host app; WidgetKit refreshes from the shared snapshot.

## Download

Download `CPAVisualize.dmg` from the project's Releases page, open the DMG, and copy `CPAVisualize.app` to `/Applications`.

The current build only supports macOS 26 because it uses Liquid Glass UI components.

## Project structure

```text
Assets/               Project icon and visual assets
CPAVisualizeApp/      Host macOS app, settings UI, sync logic, storage
CPAWidgetExtension/   WidgetKit extension and widget SwiftUI views
Shared/               Shared models and constants
scripts/              Local build, install, and packaging scripts
```

## Requirements

- macOS 26 or later.
- Xcode for local builds.
- A running Usage Keeper service.
- App Group entitlement configured for your own Apple Developer team, matching `CPAVisualizeConfiguration.appGroupIdentifier`.

## Usage

1. Open `CPAVisualize.xcodeproj` in Xcode.
2. Replace the placeholder bundle identifiers and App Group identifiers with values from your own Apple Developer account.
3. Build and run the `CPAVisualize` scheme.
4. Enter the Usage Keeper URL in the host app.
5. Enable password login if your Usage Keeper instance requires it.
6. Save settings and wait for the shared snapshot to sync.
7. Add the `CPA Usage` widget to the desktop.

## Local rebuild and install

```bash
./scripts/rebuild-and-install.sh
```

The script intentionally keeps UserDefaults and Keychain values while clearing build products and widget runtime caches.

## Build a DMG

```bash
./scripts/build-dmg.sh
```

The generated file is written to `dist/CPAVisualize.dmg` and uses the project icon from `Assets/CPAVisualize.icns`.

## Icon

The project icon is stored in `Assets/app-icon.svg`, with a generated macOS icon at `Assets/CPAVisualize.icns`. The chart metaphor was selected from the MIT-licensed Tabler Icons `chart-area-line` direction and adapted into a custom project icon.

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.
