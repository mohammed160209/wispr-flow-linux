#!/usr/bin/env bash
#===============================================================================
# install.sh -- Turnkey static installer for Wispr Flow on Arch Linux, CachyOS,
# Debian/Ubuntu, Fedora, and any modern Linux distribution.
#
# Installs:
#   1. OS runtime dependencies (PipeWire + pipewire-pulse, wl-clipboard, etc.)
#   2. Prebuilt AppImage (extracted cleanly under ~/.local/share/wispr-flow so
#      there is no FUSE runtime overhead) with SHA-256 verification
#   3. User launcher ~/.local/bin/wispr-flow (auto-enables WISPR_USE_X11=1 on
#      GNOME Wayland for unclipped dynamic XShape pills)
#   4. Desktop launcher + icon (+ optional XDG autostart & /dev/uinput rule)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mohammed160209/wispr-flow-linux/main/install.sh | bash
#   ./install.sh [options]
#
# Options:
#   --from-source   Build helper + patched AppImage locally from GitHub sources
#   --no-udev       Skip /dev/uinput udev rule setup
#   --autostart     Also add XDG autostart entry (~/.config/autostart)
#   --uninstall     Remove user installation files cleanly
#   -h, --help      Show help
#===============================================================================
set -euo pipefail

REPO_OWNER='mohammed160209'
REPO_NAME='wispr-flow-linux'
HELPER_REPO_NAME='wispr-flow-helper'
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
HELPER_REPO_URL="https://github.com/${REPO_OWNER}/${HELPER_REPO_NAME}"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

INSTALL_DIR="${DATA_HOME}/wispr-flow"
WRAPPER_BIN="${BIN_HOME}/wispr-flow"
DESKTOP_FILE="${DATA_HOME}/applications/wispr-flow.desktop"
AUTOSTART_FILE="${CONFIG_HOME}/autostart/wispr-flow.desktop"
ICON_PNG_256="${DATA_HOME}/icons/hicolor/256x256/apps/wispr-flow.png"
ICON_SVG="${DATA_HOME}/icons/hicolor/scalable/apps/wispr-flow.svg"
ICON_APP_PNG="${DATA_HOME}/icons/hicolor/256x256/apps/ai.wisprflow.WisprFlow.png"
ICON_APP_SVG="${DATA_HOME}/icons/hicolor/scalable/apps/ai.wisprflow.WisprFlow.svg"

FROM_SOURCE=false
SKIP_UDEV=false
ENABLE_AUTOSTART=false
UNINSTALL=false

if [[ -t 1 ]]; then
	GREEN='\033[0;32m'
	YELLOW='\033[0;33m'
	RED='\033[0;31m'
	BOLD='\033[1m'
	RESET='\033[0m'
else
	GREEN='' YELLOW='' RED='' BOLD='' RESET=''
fi

info() { printf '%b==>%b %s\n' "${GREEN}${BOLD}" "${RESET}" "$*"; }
warn() { printf '%bWarning:%b %s\n' "${YELLOW}${BOLD}" "${RESET}" "$*" >&2; }
die()  { printf '%bError:%b %s\n' "${RED}${BOLD}" "${RESET}" "$*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Usage: install.sh [options]

Static one-command installer for Wispr Flow on Linux (Arch/CachyOS/Ubuntu/Fedora).

Options:
  --from-source   Build the Rust helper and patched AppImage from source
  --no-udev       Skip /dev/uinput permission setup (push-to-talk / paste)
  --autostart     Enable autostart on desktop login
  --uninstall     Uninstall Wispr Flow user files cleanly
  -h, --help      Show this help message and exit
EOF
}

while (( $# > 0 )); do
	case "$1" in
		--from-source) FROM_SOURCE=true ;;
		--no-udev|--skip-udev) SKIP_UDEV=true ;;
		--autostart) ENABLE_AUTOSTART=true ;;
		--uninstall) UNINSTALL=true ;;
		-h|--help) usage; exit 0 ;;
		*) die "Unknown option: $1 (use --help for usage)" ;;
	esac
	shift
done

if (( EUID == 0 )); then
	die 'Run install.sh as your normal user, NOT with sudo. It will invoke sudo only if packages or udev rules need installation.'
fi

if [[ $UNINSTALL == true ]]; then
	info 'Removing Wispr Flow user installation...'
	rm -rf "$INSTALL_DIR"
	rm -f "$WRAPPER_BIN" "$DESKTOP_FILE" "$AUTOSTART_FILE" "$ICON_PNG_256" "$ICON_SVG" "$ICON_APP_PNG" "$ICON_APP_SVG"
	command -v gtk-update-icon-cache >/dev/null 2>&1 \
		&& gtk-update-icon-cache -f -t "${DATA_HOME}/icons/hicolor" 2>/dev/null || true
	command -v update-desktop-database >/dev/null 2>&1 \
		&& update-desktop-database "${DATA_HOME}/applications" 2>/dev/null || true
	info 'Uninstalled cleanly. User settings under ~/.config/Wispr Flow were preserved.'
	exit 0
fi

# --- Architecture check -------------------------------------------------------
RAW_ARCH="$(uname -m)"
case "$RAW_ARCH" in
	x86_64|amd64) ARCH='x86_64' ;;
	aarch64|arm64) ARCH='aarch64' ;;
	*) die "Unsupported architecture: $RAW_ARCH" ;;
esac

# --- Distro detection & runtime dependency check ------------------------------
DISTRO_FAMILY='unknown'
if [[ -f /etc/arch-release ]] || ([[ -f /etc/os-release ]] && grep -Eqi '^ID(_LIKE)?=.*arch' /etc/os-release); then
	DISTRO_FAMILY='arch'
elif [[ -f /etc/debian_version ]]; then
	DISTRO_FAMILY='debian'
elif [[ -f /etc/fedora-release || -f /etc/redhat-release ]]; then
	DISTRO_FAMILY='rpm'
fi

install_runtime_deps() {
	info "Checking system runtime dependencies ($DISTRO_FAMILY)..."
	local missing=()
	case "$DISTRO_FAMILY" in
		arch)
			local pkgs=(pipewire pipewire-pulse libpulse wl-clipboard xclip gtk3 nss alsa-lib curl desktop-file-utils)
			local p
			for p in "${pkgs[@]}"; do
				if ! pacman -Q "$p" >/dev/null 2>&1; then
					missing+=("$p")
				fi
			done
			if (( ${#missing[@]} > 0 )); then
				info "Installing missing Arch/CachyOS packages: ${missing[*]}"
				sudo pacman -S --needed --noconfirm "${missing[@]}"
			fi
			;;
		debian)
			local gtk_pkg='libgtk-3-0'
			apt-cache show libgtk-3-0t64 >/dev/null 2>&1 && gtk_pkg='libgtk-3-0t64'
			local asound_pkg='libasound2'
			apt-cache show libasound2t64 >/dev/null 2>&1 && asound_pkg='libasound2t64'
			local pkgs=(pipewire-pulse libpulse0 wl-clipboard xclip curl desktop-file-utils "$gtk_pkg" libnss3 "$asound_pkg" libxtst6 libxss1 libnotify4)
			local p
			for p in "${pkgs[@]}"; do
				if ! dpkg -s "$p" >/dev/null 2>&1; then
					missing+=("$p")
				fi
			done
			if (( ${#missing[@]} > 0 )); then
				info "Installing missing Debian/Ubuntu packages: ${missing[*]}"
				sudo apt-get update && sudo apt-get install -y "${missing[@]}"
			fi
			;;
		rpm)
			local pkgs=(pipewire-pulseaudio pipewire-libs wl-clipboard xclip curl desktop-file-utils gtk3 nss alsa-lib)
			local p
			for p in "${pkgs[@]}"; do
				if ! rpm -q "$p" >/dev/null 2>&1; then
					missing+=("$p")
				fi
			done
			if (( ${#missing[@]} > 0 )); then
				info "Installing missing Fedora/RPM packages: ${missing[*]}"
				sudo dnf install -y "${missing[@]}"
			fi
			;;
		*)
			warn "Unrecognized distro. Ensure pipewire, pipewire-pulse, wl-clipboard, xclip, gtk3, nss, and alsa-lib are installed."
			;;
	esac
}

install_runtime_deps

# --- Obtain AppImage (release download or --from-source build) ----------------
WORK_TMP="$(mktemp -d)"
cleanup() { rm -rf "$WORK_TMP"; }
trap cleanup EXIT

APPIMAGE_PATH=''

if [[ $FROM_SOURCE == true ]]; then
	info 'Building Wispr Flow Linux + Rust PipeWire helper from source...'
	command -v git >/dev/null 2>&1 || die 'git is required for --from-source'
	command -v cargo >/dev/null 2>&1 || die 'Rust cargo is required for --from-source'

	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	if [[ -f "$SCRIPT_DIR/build.sh" && -f "$SCRIPT_DIR/helper-version.txt" ]]; then
		LINUX_REPO_DIR="$SCRIPT_DIR"
	else
		LINUX_REPO_DIR="$WORK_TMP/wispr-flow-linux"
		git clone --depth 1 "$REPO_URL.git" "$LINUX_REPO_DIR"
	fi

	HELPER_REPO_DIR="$LINUX_REPO_DIR/../wispr-flow-helper"
	if [[ ! -f "$HELPER_REPO_DIR/Cargo.toml" ]]; then
		HELPER_REPO_DIR="$WORK_TMP/wispr-flow-helper"
		git clone --depth 1 "$HELPER_REPO_URL.git" "$HELPER_REPO_DIR"
	fi

	info "Building native helper in ${HELPER_REPO_DIR}..."
	(cd "$HELPER_REPO_DIR" && cargo build --release)
	BUILT_HELPER="$HELPER_REPO_DIR/target/release/wispr-flow-linux-helper"
	[[ -x $BUILT_HELPER ]] || die "Helper binary missing at $BUILT_HELPER"

	info "Running build.sh in ${LINUX_REPO_DIR}..."
	(cd "$LINUX_REPO_DIR" && HELPER_BIN="$BUILT_HELPER" ./build.sh -b appimage)
	APPIMAGE_PATH="$(find "$LINUX_REPO_DIR/build-linux/appimage" -maxdepth 1 -name '*.AppImage' | sort | tail -1)"
	[[ -n $APPIMAGE_PATH && -f $APPIMAGE_PATH ]] || die 'From-source AppImage build did not produce an .AppImage file'
else
	info "Fetching latest release metadata from ${REPO_OWNER}/${REPO_NAME}..."
	API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
	RELEASE_JSON="$WORK_TMP/release.json"
	curl -fsSL "$API_URL" -o "$RELEASE_JSON" \
		|| die "Failed to query ${API_URL}. Try '--from-source' to build locally."

	ASSET_URL="$(python3 - "$RELEASE_JSON" "$ARCH" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
arch = sys.argv[2]
assets = data.get("assets", [])
for a in assets:
    name = a.get("name", "")
    if name.endswith(".AppImage") and (arch in name or ("-" not in name.replace("wispr-flow-", "") or arch == "x86_64")):
        if "arm64" in name or "aarch64" in name:
            if arch != "aarch64":
                continue
        print(a["browser_download_url"])
        break
PY
)"
	[[ -n $ASSET_URL ]] || die "No AppImage asset found for architecture '$ARCH' in latest release. Try '--from-source'."

	ASSET_NAME="$(basename "$ASSET_URL")"
	APPIMAGE_PATH="$WORK_TMP/$ASSET_NAME"
	info "Downloading $ASSET_NAME..."
	curl -fSL --progress-bar "$ASSET_URL" -o "$APPIMAGE_PATH"

	SUMS_URL="$(python3 - "$RELEASE_JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for a in data.get("assets", []):
    if a.get("name") == "SHA256SUMS.txt":
        print(a["browser_download_url"])
        break
PY
)"
	if [[ -n $SUMS_URL ]]; then
		info 'Verifying SHA-256 digest...'
		curl -fsSL "$SUMS_URL" -o "$WORK_TMP/SHA256SUMS.txt"
		EXPECTED="$(grep -F "$ASSET_NAME" "$WORK_TMP/SHA256SUMS.txt" | awk '{print $1}' | head -1 || true)"
		if [[ -n $EXPECTED ]]; then
			ACTUAL="$(sha256sum "$APPIMAGE_PATH" | awk '{print $1}')"
			[[ $ACTUAL == "$EXPECTED" ]] || die "SHA-256 mismatch! expected=$EXPECTED actual=$ACTUAL"
			info "SHA-256 verified: $ACTUAL"
		fi
	fi
fi

# --- Static extraction into ~/.local/share/wispr-flow -------------------------
info "Installing statically into ${INSTALL_DIR}..."
chmod +x "$APPIMAGE_PATH"
(cd "$WORK_TMP" && "$APPIMAGE_PATH" --appimage-extract >/dev/null)
[[ -d "$WORK_TMP/squashfs-root" ]] || die 'AppImage extraction failed'

if pgrep -x wispr-flow >/dev/null 2>&1; then
	warn 'Stopping running Wispr Flow instance before updating files...'
	pkill -x wispr-flow || true
	sleep 1
fi

rm -rf "$INSTALL_DIR"
mkdir -p "$(dirname "$INSTALL_DIR")"
mv "$WORK_TMP/squashfs-root" "$INSTALL_DIR"

# --- Wrapper command (~/.local/bin/wispr-flow) --------------------------------
mkdir -p "$BIN_HOME"
cat > "$WRAPPER_BIN" <<EOF
#!/usr/bin/env bash
# Auto-generated by wispr-flow-linux install.sh
if [[ -z \${WISPR_USE_X11:-} && -z \${WISPR_USE_WAYLAND:-} && \${XDG_CURRENT_DESKTOP:-} == *GNOME* ]]; then
	export WISPR_USE_X11=1
fi
exec "${INSTALL_DIR}/AppRun" "\$@"
EOF
chmod 0755 "$WRAPPER_BIN"

# --- Desktop entry & icons ----------------------------------------------------
mkdir -p "$(dirname "$DESKTOP_FILE")" \
	"$(dirname "$ICON_PNG_256")" \
	"$(dirname "$ICON_SVG")"

SRC_PNG="$(find "$INSTALL_DIR" -path '*/256x256/*' -name '*.png' | head -1 || true)"
[[ -n $SRC_PNG ]] || SRC_PNG="$(find "$INSTALL_DIR" -name '*.png' | sort | tail -1 || true)"
if [[ -n $SRC_PNG ]]; then
	install -Dm644 "$SRC_PNG" "$ICON_PNG_256"
	install -Dm644 "$SRC_PNG" "$ICON_APP_PNG"
fi

SRC_SVG="$(find "$INSTALL_DIR" -name '*.svg' | head -1 || true)"
if [[ -n $SRC_SVG ]]; then
	install -Dm644 "$SRC_SVG" "$ICON_SVG"
	install -Dm644 "$SRC_SVG" "$ICON_APP_SVG"
fi

if [[ ! -f "${DATA_HOME}/icons/hicolor/index.theme" && -f /usr/share/icons/hicolor/index.theme ]]; then
	install -Dm644 /usr/share/icons/hicolor/index.theme "${DATA_HOME}/icons/hicolor/index.theme"
fi
command -v gtk-update-icon-cache >/dev/null 2>&1 \
	&& gtk-update-icon-cache -f -t "${DATA_HOME}/icons/hicolor" 2>/dev/null || true

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Wispr Flow
Comment=Voice dictation and AI Notetaker with PipeWire system audio capture
GenericName=Voice Dictation
Exec=${WRAPPER_BIN} %U
Icon=wispr-flow
Terminal=false
Type=Application
Categories=Utility;AudioVideo;Audio;
StartupNotify=true
StartupWMClass=wispr-flow
SingleMainWindow=true
Keywords=voice;dictation;speech;transcription;notetaker;pipewire;
EOF

if [[ $ENABLE_AUTOSTART == true ]]; then
	mkdir -p "$(dirname "$AUTOSTART_FILE")"
	cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Wispr Flow
Exec=${WRAPPER_BIN} --hidden
TryExec=${WRAPPER_BIN}
Icon=wispr-flow
StartupWMClass=wispr-flow
Terminal=false
X-GNOME-Autostart-enabled=true
X-Wispr-Flow-Linux-Autostart=true
EOF
	info "Autostart enabled at $AUTOSTART_FILE"
fi

command -v update-desktop-database >/dev/null 2>&1 \
	&& update-desktop-database "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true

# --- /dev/uinput & input group setup ------------------------------------------
if [[ $SKIP_UDEV == false && ! -w /dev/uinput ]]; then
	info 'Configuring /dev/uinput access for global push-to-talk and text pasting...'
	"$INSTALL_DIR/AppRun" --install-udev-rules || warn 'udev setup failed or was canceled; run wispr-flow --install-udev-rules later.'
fi

# --- Diagnostics & PipeWire verification --------------------------------------
info 'Running built-in diagnostics...'
"$WRAPPER_BIN" --doctor || warn 'Some doctor checks reported warnings/failures above.'

if command -v pactl >/dev/null 2>&1; then
	SERVER_LINE="$(pactl info 2>/dev/null | grep -E '^Server Name:' || true)"
	[[ -n $SERVER_LINE ]] && info "Audio server: ${SERVER_LINE#Server Name: }"
fi

if [[ ":${PATH}:" != *":${BIN_HOME}:"* ]]; then
	warn "${BIN_HOME} is not in your PATH. Add 'export PATH=\"${BIN_HOME}:\$PATH\"' to your ~/.bashrc or ~/.zshrc."
fi

cat <<EOF

${GREEN}${BOLD}Wispr Flow installed successfully!${RESET}
  Version : $("$WRAPPER_BIN" --version 2>/dev/null || echo 'installed')
  Command : ${WRAPPER_BIN}
  Data dir: ${INSTALL_DIR}

Notes:
  • Launch Wispr Flow from your application menu or run:  wispr-flow &
  • For Notetaker system audio + mic switching, click the system tray icon -> Notetaker Audio Input.
  • If using GNOME Wayland for the first time, log out and log back in once so GNOME Shell loads the Window Bridge extension.
EOF
