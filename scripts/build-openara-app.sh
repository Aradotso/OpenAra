#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="debug"
arch_mode="native"
codesign_mode="${OPENARA_CODESIGN_MODE:-auto}"
codesign_identity="${OPENARA_CODESIGN_IDENTITY:-}"
codesign_keychain="${OPENARA_CODESIGN_KEYCHAIN:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/build-openara-app.sh [debug|release] [--configuration debug|release] [--arch native|arm64|x86_64|universal]

Examples:
  ./scripts/build-openara-app.sh debug
  ./scripts/build-openara-app.sh --configuration release --arch universal

Environment:
  OPENARA_CODESIGN_MODE=auto|identity|adhoc|none
  OPENARA_CODESIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)"
  OPENARA_CODESIGN_KEYCHAIN=/path/to/signing.keychain-db
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    debug|release)
      configuration="$1"
      shift
      ;;
    --configuration)
      configuration="${2:-}"
      if [[ -z "${configuration}" ]]; then
        echo "--configuration requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --arch)
      arch_mode="${2:-}"
      if [[ -z "${arch_mode}" ]]; then
        echo "--arch requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${configuration}" != "debug" && "${configuration}" != "release" ]]; then
  echo "Unsupported configuration: ${configuration}" >&2
  exit 1
fi

if [[ "${arch_mode}" != "native" && "${arch_mode}" != "arm64" && "${arch_mode}" != "x86_64" && "${arch_mode}" != "universal" ]]; then
  echo "Unsupported arch mode: ${arch_mode}" >&2
  exit 1
fi

if [[ "${codesign_mode}" != "auto" && "${codesign_mode}" != "identity" && "${codesign_mode}" != "adhoc" && "${codesign_mode}" != "none" ]]; then
  echo "Unsupported OPENARA_CODESIGN_MODE: ${codesign_mode}" >&2
  exit 1
fi

read_package_version() {
  python3 - "${repo_root}/plugins/openara/.codex-plugin/plugin.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    manifest = json.load(fh)

print(manifest["version"])
PY
}

build_binary() {
  local triple="${1:-}"
  local scratch_path="${2:-}"
  local -a args=(-c "${configuration}")

  if [[ -n "${triple}" ]]; then
    args+=(--triple "${triple}")
  fi

  if [[ -n "${scratch_path}" ]]; then
    args+=(--scratch-path "${scratch_path}")
  fi

  local binary_dir
  binary_dir="$(swift build "${args[@]}" --show-bin-path)"
  swift build "${args[@]}" --product OpenAra >&2
  printf '%s/OpenAra\n' "${binary_dir}"
}

find_codesign_identity() {
  local prefix="${1:-}"
  local -a args=(find-identity -v -p codesigning)

  if [[ -n "${codesign_keychain}" ]]; then
    args+=("${codesign_keychain}")
  fi

  security "${args[@]}" 2>/dev/null \
    | sed -n "s/.*\"\\(${prefix}: .*\\)\"/\1/p" \
    | head -n 1
}

list_user_keychains() {
  security list-keychains -d user \
    | sed -n 's/^[[:space:]]*"\(.*\)"$/\1/p'
}

run_with_codesign_keychain() {
  local keychain_path="${1:-}"
  shift

  if [[ -z "${keychain_path}" ]]; then
    "$@"
    return
  fi

  local -a existing_keychains=()
  while IFS= read -r keychain; do
    if [[ -n "${keychain}" ]]; then
      existing_keychains+=("${keychain}")
    fi
  done < <(list_user_keychains)

  local -a desired_keychains=("${keychain_path}")
  local existing=""
  for existing in "${existing_keychains[@]}"; do
    if [[ "${existing}" != "${keychain_path}" ]]; then
      desired_keychains+=("${existing}")
    fi
  done

  security list-keychains -d user -s "${desired_keychains[@]}" >/dev/null

  local status=0
  "$@" || status=$?

  if [[ ${#existing_keychains[@]} -gt 0 ]]; then
    security list-keychains -d user -s "${existing_keychains[@]}" >/dev/null
  else
    security list-keychains -d user -s >/dev/null
  fi

  return "${status}"
}

resolve_codesign_identity() {
  case "${codesign_mode}" in
    none)
      return 1
      ;;
    adhoc)
      printf '%s\n' "-"
      return 0
      ;;
    identity)
      if [[ -z "${codesign_identity}" ]]; then
        echo "OPENARA_CODESIGN_IDENTITY is required when OPENARA_CODESIGN_MODE=identity" >&2
        exit 1
      fi
      printf '%s\n' "${codesign_identity}"
      return 0
      ;;
    auto)
      if [[ -n "${codesign_identity}" ]]; then
        printf '%s\n' "${codesign_identity}"
        return 0
      fi

      local discovered_identity
      discovered_identity="$(find_codesign_identity "Developer ID Application")"
      if [[ -n "${discovered_identity}" ]]; then
        printf '%s\n' "${discovered_identity}"
        return 0
      fi

      discovered_identity="$(find_codesign_identity "Apple Development")"
      if [[ -n "${discovered_identity}" ]]; then
        printf '%s\n' "${discovered_identity}"
        return 0
      fi

      printf '%s\n' "-"
      return 0
      ;;
  esac
}

codesign_app_bundle() {
  local app_path="${1:-}"
  local identity=""

  if ! identity="$(resolve_codesign_identity)"; then
    echo "Skipping codesign for ${app_path} (OPENARA_CODESIGN_MODE=none)" >&2
    return
  fi

  local -a args=(--force --deep --sign "${identity}")

  if [[ -n "${codesign_keychain}" && "${identity}" != "-" ]]; then
    args+=(--keychain "${codesign_keychain}")
  fi

  if [[ "${identity}" != "-" ]]; then
    # Hardened Runtime + Apple secure timestamp are both required for
    # `xcrun notarytool` to accept the bundle. Skip them only for ad-hoc.
    args+=(--options runtime --timestamp)
  fi

  run_with_codesign_keychain "${codesign_keychain}" \
    codesign "${args[@]}" "${app_path}" >/dev/null

  if [[ "${identity}" == "-" ]]; then
    echo "Signed ${app_path} with ad-hoc identity; macOS TCC may still treat separately built copies as different app identities until a stable Apple signing identity is configured." >&2
  else
    echo "Signed ${app_path} with ${identity}" >&2
  fi
}

cd "${repo_root}"

package_version="$(read_package_version)"
bundle_version="${OPENARA_BUNDLE_VERSION:-$(git -C "${repo_root}" rev-list --count HEAD 2>/dev/null || echo 1)}"
release_app_bundle_name="OpenAra.app"
development_app_bundle_name="OpenAra (Dev).app"
bundle_icon_name="OpenAra.icns"
icon_master_png="${repo_root}/assets/app-icons/openara-1024.png"
iconset_build_script="${repo_root}/scripts/build-apple-iconset.sh"
cursor_reference_source="${repo_root}/packages/OpenAraKit/Sources/OpenAraKit/Resources/official-software-cursor-window-252.png"

bundle_display_name="OpenAra"
bundle_identifier="so.ara.openara"
app_variant="release"
app_bundle_name="${release_app_bundle_name}"

if [[ "${configuration}" != "release" ]]; then
  bundle_display_name="OpenAra (Dev)"
  bundle_identifier="so.ara.openara.dev"
  app_variant="dev"
  app_bundle_name="${development_app_bundle_name}"
fi

app_root="${repo_root}/dist/${app_bundle_name}"
release_app_root="${repo_root}/dist/${release_app_bundle_name}"
development_app_root="${repo_root}/dist/${development_app_bundle_name}"
contents_dir="${app_root}/Contents"
macos_dir="${contents_dir}/MacOS"
resources_dir="${contents_dir}/Resources"

rm -rf "${app_root}"
if [[ "${app_variant}" == "release" ]]; then
  rm -rf "${development_app_root}"
else
  rm -rf "${release_app_root}"
fi
mkdir -p "${macos_dir}" "${resources_dir}"

case "${arch_mode}" in
  native)
    cp "$(build_binary "" "")" "${macos_dir}/OpenAra"
    ;;
  arm64)
    cp "$(build_binary "arm64-apple-macosx14.0" ".build/arm64-${configuration}")" "${macos_dir}/OpenAra"
    ;;
  x86_64)
    cp "$(build_binary "x86_64-apple-macosx14.0" ".build/x86_64-${configuration}")" "${macos_dir}/OpenAra"
    ;;
  universal)
    arm_binary="$(build_binary "arm64-apple-macosx14.0" ".build/arm64-${configuration}")"
    x86_binary="$(build_binary "x86_64-apple-macosx14.0" ".build/x86_64-${configuration}")"
    lipo -create -output "${macos_dir}/OpenAra" "${arm_binary}" "${x86_binary}"
    ;;
esac

chmod +x "${macos_dir}/OpenAra"

if [[ ! -f "${icon_master_png}" ]]; then
  echo "Missing icon master PNG: ${icon_master_png}" >&2
  exit 1
fi

if [[ ! -f "${iconset_build_script}" ]]; then
  echo "Missing iconset build script: ${iconset_build_script}" >&2
  exit 1
fi

if [[ ! -f "${cursor_reference_source}" ]]; then
  echo "Missing cursor reference PNG: ${cursor_reference_source}" >&2
  exit 1
fi

icon_work_dir="$(mktemp -d "${TMPDIR:-/tmp}/openara-icon.XXXXXX")"
cleanup() {
  if [[ -n "${icon_work_dir:-}" ]]; then
    rm -rf "${icon_work_dir}"
  fi
}
trap cleanup EXIT
iconset_dir="${icon_work_dir}/OpenAra.iconset"
mkdir -p "${iconset_dir}"
"${iconset_build_script}" "${icon_master_png}" "${iconset_dir}"
iconutil -c icns "${iconset_dir}" -o "${resources_dir}/${bundle_icon_name}"
cp "${cursor_reference_source}" "${resources_dir}/official-software-cursor-window-252.png"

# Copy the OpenAraKit SwiftPM resource bundle so Bundle.module-backed assets
# (cursor glyphs, brand fonts, logo) resolve at runtime inside the .app.
kit_bundle_name="OpenAra_OpenAraKit.bundle"
copy_kit_bundle() {
  local source_dir="$1"
  local dest_dir="${resources_dir}/${kit_bundle_name}"
  rm -rf "${dest_dir}"
  mkdir -p "${dest_dir}"
  cp -R "${source_dir}/." "${dest_dir}/"
}

case "${arch_mode}" in
  arm64|universal)
    arm_kit_bundle="${repo_root}/.build/arm64-${configuration}/arm64-apple-macosx/${configuration}/${kit_bundle_name}"
    if [[ -d "${arm_kit_bundle}" ]]; then
      copy_kit_bundle "${arm_kit_bundle}"
    fi
    ;;
  x86_64)
    x86_kit_bundle="${repo_root}/.build/x86_64-${configuration}/x86_64-apple-macosx/${configuration}/${kit_bundle_name}"
    if [[ -d "${x86_kit_bundle}" ]]; then
      copy_kit_bundle "${x86_kit_bundle}"
    fi
    ;;
  native)
    native_kit_bundle="$(swift build -c "${configuration}" --show-bin-path)/${kit_bundle_name}"
    if [[ -d "${native_kit_bundle}" ]]; then
      copy_kit_bundle "${native_kit_bundle}"
    fi
    ;;
esac

if [[ ! -d "${resources_dir}/${kit_bundle_name}" ]]; then
  echo "Warning: ${kit_bundle_name} was not copied into ${resources_dir}; brand cursors and fonts may not appear." >&2
fi

cat > "${contents_dir}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>OpenAra</string>
  <key>CFBundleIconFile</key>
  <string>${bundle_icon_name%.icns}</string>
  <key>CFBundleIconName</key>
  <string>${bundle_icon_name%.icns}</string>
  <key>CFBundleIdentifier</key>
  <string>${bundle_identifier}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${bundle_display_name}</string>
  <key>CFBundleDisplayName</key>
  <string>${bundle_display_name}</string>
  <key>OpenAraAppVariant</key>
  <string>${app_variant}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${package_version}</string>
  <key>CFBundleVersion</key>
  <string>${bundle_version}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAccessibilityUsageDescription</key>
  <string>${bundle_display_name} drives other apps through the macOS accessibility APIs so AI agents you connect via MCP can read window state and click, type, and scroll on your behalf.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>${bundle_display_name} sends Apple Events to focus and interact with other apps when accessibility actions need to fall back to scripted control.</string>
  <key>NSScreenCaptureDescription</key>
  <string>${bundle_display_name} captures the screen so MCP clients can see what the agent is looking at while it works.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "${contents_dir}/Info.plist" >/dev/null
codesign_app_bundle "${app_root}"

echo "Built ${app_root} (${arch_mode}, ${configuration})"
