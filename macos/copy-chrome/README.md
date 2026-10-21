# copy-chrome

🇬🇧 English | 🇫🇷 [Français](README.fr.md)

Make independent copies of Google Chrome on macOS: one Chrome per Google account, each
one with its own icon in the Dock and its own entry in Cmd+Tab.

## Why

On macOS, all Chrome profiles live in **one app**. The Dock and Cmd+Tab show **one**
Chrome for all of them. To go from your personal window to your work window, you need
Cmd+`, the Window menu or Mission Control.

With `copy-chrome`, "Google Chrome" and "Chrome Work" are two apps. Each one has its own
Dock icon (with a round badge if you want), its own Cmd+Tab entry and its own windows.

## How it works

The script copies `Google Chrome.app` and changes three things in the copy:

- a new bundle id (`com.google.Chrome.<Id>`): macOS sees a separate app;
- a new name (`Chrome <name>`);
- a new data folder (`~/Library/Application Support/Google/Chrome<Id>`): the copy starts
  empty, and the original Chrome is not touched.

Then it signs the copy again on your Mac (ad hoc signature).

`<Id>` is the name without spaces and other non-alphanumeric characters.

## Requirements

- macOS, with Google Chrome in `/Applications`.
- Xcode Command Line Tools (`xcode-select --install`), only for `--badge`: the icon is
  drawn with `swift`.
- About 1.4 GB of free space per copy.

## Install

Download `copy-chrome.sh` and `make-icon.swift` into **the same folder**, then:

```sh
chmod +x copy-chrome.sh
```

## Usage

```sh
./copy-chrome.sh <name> [--badge <image> | --no-badge] [--force] [--yes] [--src <app>] [--dest <folder>]
./copy-chrome.sh <name> --remove [--yes] [--dest <folder>]
```

| Option             | What it does                                                         |
|--------------------|----------------------------------------------------------------------|
| `<name>`           | the copy is `Chrome <name>.app`. Use quotes if the name has spaces.  |
| `--badge <image>`  | put the image (round, top left) on the Chrome icon                   |
| `--no-badge`       | go back to the normal Chrome icon                                    |
| `--force`          | rebuild the copy even when it is up to date                          |
| `--remove`         | remove the copy and its data                                         |
| `--yes`            | answer yes to all questions                                          |
| `--src <app>`      | the original Chrome (default: `/Applications/Google Chrome.app`)     |
| `--dest <folder>`  | where the copy goes (default: `~/Applications`)                      |

Without `--badge`, a new copy has the Chrome icon, and an update keeps the icon of the
old copy.

## Examples

Create a copy with a badge:

```sh
./copy-chrome.sh Work --badge ~/Pictures/company-logo.png
```

Update the copy after an update of Chrome (quit Chrome first):

```sh
./copy-chrome.sh Work
```

Change the badge, or remove it:

```sh
./copy-chrome.sh Work --badge other-logo.png
./copy-chrome.sh Work --no-badge
```

Remove the copy and all its data (profile, history, cookies, cache):

```sh
./copy-chrome.sh Work --remove
```

The script asks before it replaces or removes a copy. If the copy is open, it quits it
first.

## First launch

1. Open `~/Applications/Chrome Work.app`.
2. macOS asks for access to the keychain item "Chrome Safe Storage": click
   **Always Allow**.
3. Sign in to your Google account and turn on sync.
4. Right-click the Dock icon: **Options > Keep in Dock**.

## Limits

- **Passkeys saved on the Mac are not offered** in a copy (Apple Passwords, Google
  Password Manager). Passwords work, and a passkey on your phone works with the QR code
  ("Use a passkey from another device"). Keep the accounts that use many passkeys in
  the original Chrome.
- **The keychain asks again** for access after each update of the copy: click
  **Always Allow**.
- **No automatic update**: run the script again after each update of Chrome.
- **Not official**: Google does not support this. It can stop working with a future
  version of Chrome or macOS.

## More details

How it works, all the limits and the alternatives: see the blog article (link coming
soon).
