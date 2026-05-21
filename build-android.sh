#!/usr/bin/env bash
# build-android.sh — Local equivalent of the android-release GitHub Actions workflow.
# Signing is optional: copy .env.android.example to .env.android and fill in
# your keystore values, or set the vars in the environment directly.
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}==>${NC} $*"; }
warn()  { echo -e "${YELLOW}warn:${NC} $*"; }
die()   { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

# ── Load .env.android if present ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.android"
if [[ -f "$ENV_FILE" ]]; then
  info "Loading $ENV_FILE"
  # Export each non-comment, non-blank line; skip lines already set in env.
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue   # skip comments
    [[ -z "${line//[[:space:]]/}" ]] && continue   # skip blank lines
    key="${line%%=*}"
    # Only set if not already exported from the shell environment
    if [[ -z "${!key+x}" ]]; then
      export "$line"
    fi
  done < "$ENV_FILE"
else
  warn ".env.android not found — signing will be skipped unless vars are already exported."
  warn "Copy .env.android.example to .env.android to configure signing."
fi

# ── 1. Java 17 ────────────────────────────────────────────────────────────────
info "Checking Java..."
if ! command -v java &>/dev/null; then
  die "Java not found. Install JDK 17 (e.g. 'sudo apt install openjdk-17-jdk' or use SDKMAN)."
fi
JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
if [[ "$JAVA_VER" -lt 17 ]]; then
  die "Java 17+ required (found Java $JAVA_VER). Set JAVA_HOME to a JDK 17 installation."
fi
info "Java OK (version $JAVA_VER)"

# ── 2. Android SDK ────────────────────────────────────────────────────────────
info "Checking Android SDK..."
if [[ -z "${ANDROID_HOME:-}" ]]; then
  # Common default locations
  for candidate in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" "/opt/android-sdk"; do
    if [[ -d "$candidate" ]]; then
      export ANDROID_HOME="$candidate"
      break
    fi
  done
fi
[[ -n "${ANDROID_HOME:-}" ]] || die "ANDROID_HOME is not set and no SDK found in common locations."
info "ANDROID_HOME=$ANDROID_HOME"

SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
[[ -x "$SDKMANAGER" ]] || die "sdkmanager not found at $SDKMANAGER. Install Android command-line tools."

# ── 3. NDK 27 ─────────────────────────────────────────────────────────────────
NDK_VERSION="27.1.12297006"
NDK_PATH="$ANDROID_HOME/ndk/$NDK_VERSION"
if [[ ! -d "$NDK_PATH" ]]; then
  info "Installing NDK $NDK_VERSION..."
  "$SDKMANAGER" "ndk;$NDK_VERSION"
else
  info "NDK $NDK_VERSION already installed"
fi
export ANDROID_NDK_ROOT="$NDK_PATH"
export NDK_HOME="$NDK_PATH"

# ── 4. Rust + Android targets ─────────────────────────────────────────────────
info "Checking Rust..."
command -v rustup &>/dev/null || die "rustup not found. Install from https://rustup.rs"
rustup show active-toolchain &>/dev/null || rustup toolchain install stable

ANDROID_TARGETS=(
  aarch64-linux-android
  armv7-linux-androideabi
  i686-linux-android
  x86_64-linux-android
)
info "Adding Android Rust targets..."
rustup target add "${ANDROID_TARGETS[@]}"

# ── 5. pnpm ───────────────────────────────────────────────────────────────────
info "Checking pnpm..."
command -v pnpm &>/dev/null || die "pnpm not found. Install with 'npm i -g pnpm' or 'corepack enable'."

# ── 6. JS dependencies ────────────────────────────────────────────────────────
info "Installing JS dependencies..."
pnpm install

# ── 7. Build APK ──────────────────────────────────────────────────────────────
info "Building APK..."
pnpm tauri android build --apk

APK_DIR="src-tauri/gen/android/app/build/outputs/apk"

# ── 8. Sign APK (optional) ────────────────────────────────────────────────────
if [[ -n "${KEYSTORE_BASE64:-}" && -n "${KEY_ALIAS:-}" && -n "${KEY_PASSWORD:-}" && -n "${STORE_PASSWORD:-}" ]]; then
  info "Signing APK..."

  UNSIGNED=$(find "$APK_DIR" -name "*unsigned*.apk" | head -1)
  [[ -n "$UNSIGNED" ]] || die "No unsigned APK found under $APK_DIR"
  SIGNED="${UNSIGNED/unsigned/signed}"

  # Locate apksigner (try common build-tools versions newest-first)
  APKSIGNER=""
  for bt in "$ANDROID_HOME/build-tools"/*/apksigner; do
    APKSIGNER="$bt"
  done
  # Sort descending and take the highest version
  APKSIGNER=$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -rV | head -1)
  [[ -x "$APKSIGNER" ]] || die "apksigner not found under $ANDROID_HOME/build-tools. Install build-tools via sdkmanager."

  echo "$KEYSTORE_BASE64" | base64 -d > release.jks
  trap 'rm -f release.jks' EXIT

  "$APKSIGNER" sign \
    --ks release.jks \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass "pass:$STORE_PASSWORD" \
    --key-pass "pass:$KEY_PASSWORD" \
    --out "$SIGNED" \
    "$UNSIGNED"

  mv "$SIGNED" "$SCRIPT_DIR/"
  info "Signed APK: $(basename "$SIGNED")"
else
  warn "Signing vars not set — skipping. Populate .env.android (see .env.android.example) to enable signing."
  UNSIGNED=$(find "$APK_DIR" -name "*.apk" | head -1)
  [[ -n "$UNSIGNED" ]] || die "No APK found under $APK_DIR — check build output."
  mv "$UNSIGNED" "$SCRIPT_DIR/"
  info "APK: $(basename "$UNSIGNED")"
fi

info "Done. Output: $SCRIPT_DIR/"
