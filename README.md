<div align="center">
  <a href="https://betterswitch.vercel.app/">
    <img src="Betterswitch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" width="128" height="128" alt="Betterswitch app icon">
  </a>

  <h1><a href="https://betterswitch.vercel.app/">Betterswitch</a></h1>

  <p>A fast, keyboard-first window switcher for macOS.</p>

  <p>
    <img alt="macOS" src="https://img.shields.io/badge/macOS-26.2%2B-blue">
    <img alt="Swift" src="https://img.shields.io/badge/Swift-5.0%2B-orange">
    <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-purple">
    <img alt="Xcode" src="https://img.shields.io/badge/Xcode-26%2B-blue">
    <img alt="App" src="https://img.shields.io/badge/App-Menu%20Bar-black">
    <img alt="Permission" src="https://img.shields.io/badge/Permission-Accessibility-brightgreen">
  </p>
</div>

Betterswitch is a macOS menu bar window switcher for quickly finding and opening running app windows.

It is built for users who want a deeper alternative to `Command + Tab`: instead of only switching between apps, Betterswitch shows the actual open windows for each running app, including multiple Chrome, Xcode, Terminal, Finder, or other app windows.

## Features

- Menu bar only app
- Customizable global keyboard shortcuts
- Default shortcut: <kbd>⌘</kbd> + <kbd>`</kbd>
- Lists open windows from running apps
- Search apps and windows by typing
- Keyboard-first navigation with Up, Down, Return, and Escape
- Smooth centered switcher overlay
- Liquid glass styled window frames
- Custom shortcut recorder from the menu bar
- Secure automatic updates powered by Sparkle

## Installation

1. Download the latest `Betterswitch.dmg` from the [Betterswitch website](https://betterswitch.vercel.app/).
2. Open the DMG.
3. Drag `Betterswitch.app` into the `Applications` folder.
4. Open Betterswitch from Applications.

On first launch, macOS may ask for Accessibility permission. Betterswitch needs this permission to read and focus windows from other apps.

## Permissions

Betterswitch uses macOS Accessibility APIs to detect and focus windows.

To enable it manually:

1. Open **System Settings**.
2. Go to **Privacy & Security > Accessibility**.
3. Enable Betterswitch.
4. Restart Betterswitch if window switching does not work immediately.
