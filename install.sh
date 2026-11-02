#!/bin/sh
set -eu

repo=shortcuts/obsidian-quickadd-macos-menubar
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The release zip needs no toolchain. Fall back to source while no release exists.
if curl -fsSL "https://github.com/$repo/releases/latest/download/QuickAddMenubar.zip" -o "$tmp/app.zip"; then
  mkdir -p ~/Applications
  ditto -x -k "$tmp/app.zip" "$tmp/out"
  pkill -x QuickAddMenubar || true
  rm -rf ~/Applications/QuickAddMenubar.app
  mv "$tmp/out/QuickAddMenubar.app" ~/Applications/
  open ~/Applications/QuickAddMenubar.app
else
  git clone --depth 1 "https://github.com/$repo" "$tmp/src"
  make -C "$tmp/src" install
fi
