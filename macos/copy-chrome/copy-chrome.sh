#!/bin/bash
# Create or update one independent copy of Google Chrome: "Chrome <name>.app".
# The copy has its own bundle id (so its own Dock icon) and its own, empty data folder.
# Run the script once per copy.
set -euo pipefail

# ---------------------------------------------------------------------------
# Default settings (the options --src and --dest change them)
# ---------------------------------------------------------------------------

# The original Chrome, used as the source of each copy.
SRC="/Applications/Google Chrome.app"

# Where the copies are created.
DEST="$HOME/Applications"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLISTBUDDY="/usr/libexec/PlistBuddy"
QUIT_TIMEOUT=30

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $0 <name> [--badge <image> | --no-badge] [--force] [--yes] [--src <app>] [--dest <folder>]
       $0 <name> --remove [--yes] [--dest <folder>]

  <name>           the copy is "Chrome <name>.app"
  --remove         remove the copy and its data (profile, history, cookies, cache,
                   preferences)
  --badge <image>  put this image (round, top left) on the Chrome icon.
                   Without it: a new copy has the Chrome icon, and an update keeps
                   the icon of the old copy.
  --no-badge       go back to the Chrome icon
  --force          rebuild the copy even when it has the Chrome version
  --yes            answer yes to the questions (update, remove, quit the open copy)
  --src <app>      original Chrome (default: $SRC)
  --dest <folder>  where the copy goes (default: $DEST)
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

usage_error() {
  echo "Error: $*" >&2
  usage >&2
  exit 1
}

# Stop if the option has no value. A value that starts with "--" is another option.
need_value() {
  if [[ $# -lt 2 || "$2" == --* ]]; then
    usage_error "$1 needs a value."
  fi
}

# Print the id of a copy: the name without non-alphanumeric characters.
copy_id() {
  printf '%s' "${1//[^a-zA-Z0-9]/}"
}

# Stop if the name cannot be used for a copy.
check_name() {
  if [[ "$1" == */* ]]; then
    fail "the name '$1' must not contain '/'."
  fi
  if [[ -z "$(copy_id "$1")" ]]; then
    fail "the name '$1' has no letter or digit."
  fi
}

# Print a plist value. Print nothing if the file or the key does not exist.
plist_get() {
  "$PLISTBUDDY" -c "Print :$2" "$1" 2>/dev/null || true
}

# Set a string value. Add the key if it does not exist yet.
plist_set() {
  local plist="$1" key="$2" value="$3"
  if ! "$PLISTBUDDY" -c "Set :$key \"$value\"" "$plist" 2>/dev/null; then
    "$PLISTBUDDY" -c "Add :$key string \"$value\"" "$plist"
  fi
}

# Return 0 if the app runs.
is_running() {
  pgrep -f "$1/" >/dev/null
}

# Ask a yes/no question. Return 0 if the answer is yes.
# assume_yes=1 (option --yes) answers yes without a question.
# Without a terminal, nobody can answer: print an error and return 1.
ask_yes() {
  local question="$1" assume_yes="$2" answer=""
  if [[ "$assume_yes" -eq 1 ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    echo "Error: no terminal to answer this question: $question" >&2
    echo "Use --yes to answer yes." >&2
    return 1
  fi
  # No answer (end of input) means no.
  if ! read -r -p "$question [y/N] " answer; then
    answer=""
  fi
  case "$answer" in
    y | Y | yes | YES)
      return 0
      ;;
  esac
  return 1
}

# Quit the copy if it runs, and wait until it stops. Ask the user before the call.
# Return 1 if it still runs after QUIT_TIMEOUT seconds.
quit_copy() {
  local app="$1" bundle_id="$2" waited=0
  if ! is_running "$app"; then
    return 0
  fi
  echo "$(basename "$app" .app): quitting the running copy..."
  # If osascript fails, the wait below reports it.
  osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null || true
  while is_running "$app"; do
    if [[ "$waited" -ge "$QUIT_TIMEOUT" ]]; then
      echo "Error: $(basename "$app" .app) still runs after ${QUIT_TIMEOUT}s. Quit it, then run the script again." >&2
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
}

# Return 0 if the app has a custom icon (put by apply_icon).
has_custom_icon() {
  local app="$1"
  [[ -f "$app/Contents/Resources/app.icns" ]] &&
    [[ -z "$(plist_get "$app/Contents/Info.plist" CFBundleIconName)" ]]
}

# Make an .icns file: the icon of the app, with the badge image on it.
# The function body runs in a subshell, so its EXIT trap does not replace the trap
# of the script.
build_icns() (
  local app="$1" badge="$2" icns="$3"
  local work_dir icon_png iconset size double
  work_dir="$(mktemp -d)"
  trap 'rm -rf "$work_dir"' EXIT
  icon_png="$work_dir/icon.png"
  iconset="$work_dir/icon.iconset"
  mkdir "$iconset"

  swift "$SCRIPT_DIR/make-icon.swift" "$app" "$badge" "$icon_png"

  for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" "$icon_png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$double" "$double" "$icon_png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done

  iconutil -c icns "$iconset" -o "$icns"
)

# Put an .icns file in the app. The app must be signed again after this.
apply_icon() {
  local app="$1" icns="$2"
  local plist="$app/Contents/Info.plist"
  cp "$icns" "$app/Contents/Resources/app.icns" || return 1
  plist_set "$plist" CFBundleIconFile "app.icns" || return 1
  # With this key, macOS takes the icon from Assets.car and ignores app.icns.
  # The key may be missing already: the error is safe to ignore.
  "$PLISTBUDDY" -c "Delete :CFBundleIconName" "$plist" 2>/dev/null || true
}

# Sign the app again (ad hoc), then check the signature.
# Needed after any change in the app (Info.plist, icon).
sign_app() {
  local app="$1"
  # Remove all extended attributes. Some Chrome files have com.apple.FinderInfo,
  # and codesign refuses it: "resource fork, Finder information, or similar detritus".
  xattr -cr "$app" || return 1
  # Sign only the main app, without --deep. Frameworks and helpers are not changed,
  # so they keep the Google signature. Also, --deep breaks the old framework version
  # that Chrome keeps after an update (Versions/<old version>).
  codesign --force --sign - "$app" || return 1
  codesign --verify --deep --strict "$app"
}

# Remove the copy and everything it leaves on the disk.
# The Keychain item "Chrome Safe Storage" is not removed: the original Chrome uses
# the same item.
remove_copy() {
  # Never empty: check_name makes sure that the name has a letter or a digit.
  # So the data folder is never the one of the original Chrome (Google/Chrome).
  local data_dir="$HOME/Library/Application Support/Google/Chrome${id:?}"
  local cache_dir="$HOME/Library/Caches/Google/Chrome$id"
  local prefs_file="$HOME/Library/Preferences/$bundle_id.plist"
  local path list="" question

  for path in "$app" "$data_dir" "$cache_dir" "$prefs_file"; do
    if [[ -e "$path" ]]; then
      list="$list  $(du -sh "$path" | cut -f1)  $path"$'\n'
    fi
  done
  if [[ -z "$list" ]]; then
    echo "$label: nothing to remove."
    return 0
  fi
  echo "$label: these items will be removed:"
  printf '%s' "$list"

  question="Remove $label and its data (profile, history, cookies)? This cannot be undone."
  if is_running "$app"; then
    question="$question It is open: it will be quit, and unsaved work in it will be lost."
  fi
  if ! ask_yes "$question" "$yes"; then
    echo "Cancelled. Nothing was removed." >&2
    exit 1
  fi

  quit_copy "$app" "$bundle_id"
  rm -rf "$app" "$data_dir" "$cache_dir"
  # macOS keeps the preferences in memory (cfprefsd): use defaults, not rm.
  # The domain may not exist: the error is safe to ignore.
  defaults delete "$bundle_id" >/dev/null 2>&1 || true
  rm -f "$prefs_file"
  echo "$label: removed."
  echo "If the copy was kept in the Dock, drag its icon out of the Dock."

  # Restart the Dock so it shows that the app is gone.
  killall Dock
}

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------

name=""
force=0
yes=0
badge=""
no_badge=0
remove=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove)
      remove=1
      shift
      ;;
    --badge)
      need_value "$@"
      badge="$2"
      shift 2
      ;;
    --no-badge)
      no_badge=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
    --yes)
      yes=1
      shift
      ;;
    --src)
      need_value "$@"
      SRC="$2"
      shift 2
      ;;
    --dest)
      need_value "$@"
      DEST="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      usage_error "unknown option: $1"
      ;;
    *)
      if [[ -n "$name" ]]; then
        usage_error "only one name is allowed. Run the script once per copy."
      fi
      name="$1"
      shift
      ;;
  esac
done

if [[ -z "$name" ]]; then
  usage_error "the name is missing."
fi
check_name "$name"

if [[ -n "$badge" && "$no_badge" -eq 1 ]]; then
  usage_error "use --badge or --no-badge, not both."
fi
if [[ "$remove" -eq 1 && ( -n "$badge" || "$no_badge" -eq 1 || "$force" -eq 1 ) ]]; then
  usage_error "--remove cannot be used with --badge, --no-badge or --force."
fi
if [[ -n "$badge" ]]; then
  if [[ ! -f "$badge" ]]; then
    fail "badge image not found: $badge"
  fi
  # A relative path is relative to the current folder.
  if [[ "$badge" != /* ]]; then
    badge="$PWD/$badge"
  fi
fi

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

mkdir -p "${DEST:?}"
# Use an absolute path: pgrep compares it with the full path of the running app.
DEST="$(cd "$DEST" && pwd)"

id="$(copy_id "$name")"
bundle_id="com.google.Chrome.$id"
label="Chrome $name"
app="$DEST/$label.app"

if [[ "$remove" -eq 1 ]]; then
  remove_copy
  exit 0
fi

if [[ ! -d "$SRC" ]]; then
  fail "$SRC not found."
fi

if pgrep -f "$SRC/Contents/MacOS/" >/dev/null; then
  echo "Warning: Google Chrome is running. If an update is waiting, the copy can be" >&2
  echo "made from an old or partial version. Quit Chrome, then run the script again." >&2
fi

new_version="$(plist_get "$SRC/Contents/Info.plist" CFBundleShortVersionString)"
if [[ -z "$new_version" ]]; then
  fail "cannot read the version of $SRC."
fi

# 1 when the user agreed that the open copy is quit.
quit_ok="$yes"
old_version=""

if [[ -d "$app" ]]; then
  old_version="$(plist_get "$app/Contents/Info.plist" CFBundleShortVersionString)"
  if [[ "$old_version" == "$new_version" && "$force" -eq 0 && -z "$badge" && "$no_badge" -eq 0 ]]; then
    echo "$label: $old_version (up to date)"
    exit 0
  fi

  # Ask now, so the user does not wait for the build before the question.
  question="$label exists (${old_version:-unknown version}). Replace it with a new copy of Chrome $new_version?"
  running=0
  if is_running "$app"; then
    running=1
    question="$question It is open: it will be quit, and unsaved work in it will be lost."
  fi
  if ! ask_yes "$question" "$yes"; then
    echo "Cancelled. $label was not changed." >&2
    exit 1
  fi
  if [[ "$running" -eq 1 ]]; then
    quit_ok=1
  fi
fi

# Build the new copy here first, then move it in place.
# So if a step fails, the old copy stays as it was.
build_dir="$DEST/.copy-chrome-$id.build"
trap 'rm -rf "$build_dir"' EXIT
rm -rf "$build_dir"
mkdir -p "$build_dir"

# Choose the icon of the new copy.
icns=""
if [[ -n "$badge" ]]; then
  icns="$build_dir/badge.icns"
  build_icns "$SRC" "$badge" "$icns"
  icon_text="badge $badge"
elif [[ "$no_badge" -eq 0 && -d "$app" ]] && has_custom_icon "$app"; then
  # Keep the icon of the old copy. The old copy is removed only after the build.
  icns="$app/Contents/Resources/app.icns"
  icon_text="kept from the old copy"
else
  icon_text="Chrome icon"
fi

new_app="$build_dir/$label.app"
cp -R "$SRC" "$new_app"

plist="$new_app/Contents/Info.plist"
plist_set "$plist" CFBundleIdentifier "$bundle_id"
plist_set "$plist" CFBundleName "$label"
plist_set "$plist" CFBundleDisplayName "$label"
# Chrome reads this key to choose its data folder in ~/Library/Application Support.
plist_set "$plist" CrProductDirName "Google/Chrome$id"

if [[ -n "$icns" ]]; then
  apply_icon "$new_app" "$icns"
fi

# The Info.plist changes break the Google signature.
sign_app "$new_app"

# The copy may have been opened during the build: ask before it is quit.
if is_running "$app" && [[ "$quit_ok" -eq 0 ]]; then
  if ! ask_yes "$label is open now. Quit it? Unsaved work in it will be lost." "$yes"; then
    echo "Cancelled. $label was not changed." >&2
    exit 1
  fi
fi
quit_copy "$app" "$bundle_id"
rm -rf "$app"
mv "$new_app" "$app"
touch "$app"
echo "$label: ${old_version:-none} -> $new_version (icon: $icon_text)"

# Restart the Dock so it shows the new icon.
killall Dock
