# Drovio

<p align="center">
  <img src="screenshot.gif" alt="Drovio UI Animation" width="480">
  <br><br>
  <img src="screenshot.png" alt="Drovio Menu Bar UI" width="480">
</p>

<p align="center">
  <b>A premium, native macOS menu bar video and image downloader. Paste. Download. Done.</b>
</p>

<p align="center">
  <a href="https://github.com/ombichave999/Drovio/releases/latest">
    <img src="https://img.shields.io/github/v/release/ombichave999/Drovio?color=blue&label=Latest%20Release" alt="Latest Release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift Version">
  <img src="https://img.shields.io/github/license/ombichave999/Drovio?color=lightgrey" alt="License">
</p>

---

**Drovio** is a lightweight, blazing-fast, and completely private downloader for macOS. Built purely with Swift 6 and SwiftUI, it sits quietly in your menu bar without cluttering your dock, ready to download media with a single click.

## Features

- [x] **Native SwiftUI Interface**: Beautiful, responsive layout with frosted-glass effects.
- [x] **Smart Clipboard Detection**: Instantly detects video/image URLs on copy and prompts you to download.
- [x] **YouTube Downloader**: Download YouTube videos and Shorts in high quality.
- [x] **Instagram Reels & Posts**: Download reels, single photos, and multi-image carousels/slideshows natively.
- [x] **Music Extraction**: Support for downloading audio-only from Spotify and Apple Music links.
- [x] **Multi-format Support**: Download in highest quality, 1080p, 720p, or extract MP3/M4A audio.
- [x] **Live Download Queue**: Manage up to 3 concurrent downloads with live progress, speed tracking, and ETAs.
- [x] **Pause / Resume / Cancel**: Full download lifecycle management.
- [x] **Native macOS Notifications**: Get notified when downloads complete and open files directly in Finder.
- [x] **Local Download History**: Keeps track of recent downloads with thumbnails.
- [x] **Launch at Login**: Easily toggle start-on-boot from Settings.
- [x] **Automatic Dependencies**: Silently downloads and updates its helper binaries (`yt-dlp` and `ffmpeg`) internally.

---

## Installation

### Method 1: Precompiled App (Recommended)
1. Go to the [Releases](https://github.com/ombichave999/Drovio/releases) page.
2. Download the latest `Drovio_1.1.4.dmg` installer.
3. Open the DMG and drag `Drovio.app` to your `/Applications` directory.

### Method 2: Build from Source
1. Clone this repository: `git clone https://github.com/ombichave999/Drovio.git`
2. Open `Drovio.xcodeproj` in Xcode 16 or newer.
3. Select the `Drovio` scheme and build/run with `⌘R`.
   *(Ad hoc signing is configured by default, so a developer account is not required to run it locally.)*

---

## Requirements

- Apple Silicon or Intel Mac
- macOS 14 Sonoma or newer
- Xcode 16+ (only if compiling from source)

---

## Roadmap

- [ ] **YouTube Playlist Support**: Download complete video playlists with one click.
- [ ] **Batch Downloads**: Paste multiple URLs at once.
- [ ] **Browser Extensions**: Quick-send links to Drovio from Chrome, Safari, and Firefox.
- [ ] **Custom Output Folders**: Custom folder rules based on download source platform.

---

## Architecture (MVVM)

```text
Drovio/
├── App/            DrovioApp, AppDelegate, AppContainer (DI composition root)
├── Models/         DownloadTask, VideoInfo, VideoQuality, HistoryItem, DownloadError
├── ViewModels/     DownloadManager (queue, scheduling, lifecycle)
├── Views/          MainView, HistoryView, SettingsView, Components/
├── Services/       DownloadEngine (actor), Toolbox (actor, tool install/update),
│                   ClipboardMonitor, NotificationManager, SettingsManager, HistoryManager
└── Utilities/      URLValidator, FilenameSanitizer, ProcessRunner, Log
```

- `DownloadEngine` is a Swift actor that manages yt-dlp processes and parses live progress data.
- `Toolbox` automates binary bootstrap checks and updates.
- Stderr/stderr streams are mapped to user-friendly errors (private, deleted, age-restricted, network, etc.).

---

## Legal

Download only content you have the right to download. Respect each platform's terms of service and copyright laws.
