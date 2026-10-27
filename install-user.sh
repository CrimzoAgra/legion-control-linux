#!/usr/bin/env bash
# Installs the app for the current user (no root needed). Run: bash install-user.sh
# Then run the root part once: sudo bash ~/.local/share/legion-control/install.sh
set -e
src=$(dirname "$(readlink -f "$0")")
dest="$HOME/.local/share/legion-control"
mkdir -p "$dest" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/scalable/apps"
install -m 644 "$src/shell.qml" "$dest/shell.qml"
install -m 755 "$src/legion-ctl" "$src/legion-rgb" "$src/install.sh" "$dest/"
install -m 755 "$src/data/legion-control" "$HOME/.local/bin/legion-control"
install -m 644 "$src/data/legion-control.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/legion-control.svg"
[[ -f $HOME/.local/share/icons/hicolor/index.theme ]] || cp /usr/share/icons/hicolor/index.theme "$HOME/.local/share/icons/hicolor/" 2>/dev/null || true
sed "s|@HOME@|$HOME|" "$src/data/legion-control.desktop" >"$HOME/.local/share/applications/legion-control.desktop"
gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
echo "Installed. Now run once: sudo bash $dest/install.sh"
