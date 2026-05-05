#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_helper="${repo_root}/scripts/install-config-helper.mjs"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
config_path="${codex_home}/config.toml"
marketplace_name="openara-local"
plugin_name="openara"
plugin_source_root="${repo_root}/plugins/${plugin_name}"
plugin_manifest="${plugin_source_root}/.codex-plugin/plugin.json"
macos_build_script="${repo_root}/scripts/build-openara-app.sh"
configuration="debug"
rebuild="false"

resolve_app_bundle() {
  local -a candidates

  if [[ "${configuration}" == "release" ]]; then
    candidates=("OpenAra.app")
  else
    candidates=("OpenAra (Dev).app" "OpenAra.app")
  fi

  for bundle_name in "${candidates[@]}"; do
    local candidate="${repo_root}/dist/${bundle_name}"
    if [[ -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild)
      rebuild="true"
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
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--rebuild] [--configuration debug|release]" >&2
      exit 1
      ;;
  esac
done

platform="$(uname)"

if [[ "${platform}" != "Darwin" ]]; then
  echo "OpenAra is macOS-only. Detected platform: ${platform}" >&2
  exit 1
fi

payload_path="$(resolve_app_bundle || true)"
app_binary="${payload_path:+${payload_path}/Contents/MacOS/OpenAra}"
if [[ "${rebuild}" == "true" || -z "${app_binary}" || ! -x "${app_binary}" ]]; then
  if [[ -x "${macos_build_script}" ]]; then
    "${macos_build_script}" "${configuration}"
    payload_path="$(resolve_app_bundle || true)"
    app_binary="${payload_path:+${payload_path}/Contents/MacOS/OpenAra}"
  else
    echo "Missing runnable app bundle at ${app_binary} and no local build script is available." >&2
    exit 1
  fi
fi
if [[ -z "${payload_path}" || ! -x "${app_binary}" ]]; then
  echo "Missing runnable app binary at ${app_binary}" >&2
  exit 1
fi

if [[ ! -f "${repo_root}/.agents/plugins/marketplace.json" ]]; then
  echo "Missing ${repo_root}/.agents/plugins/marketplace.json" >&2
  exit 1
fi

if [[ ! -f "${plugin_manifest}" ]]; then
  echo "Missing ${plugin_manifest}" >&2
  exit 1
fi

plugin_version="$(node "${config_helper}" codex-plugin-version "${plugin_manifest}")"

if [[ -z "${plugin_version}" ]]; then
  echo "Failed to read plugin version from ${plugin_manifest}" >&2
  exit 1
fi

plugin_cache_root="${codex_home}/plugins/cache/${marketplace_name}/${plugin_name}"
plugin_install_root="${plugin_cache_root}/${plugin_version}"

mkdir -p "${codex_home}" "${plugin_cache_root}"
rm -rf "${plugin_install_root}"
mkdir -p "${plugin_install_root}"

node "${config_helper}" copy-into-dir "${plugin_install_root}" "${plugin_source_root}" "${payload_path}"

node "${config_helper}" codex-plugin-config "${config_path}" "${repo_root}" "${marketplace_name}" "${plugin_name}"

echo "Installed ${plugin_name}@${marketplace_name}"
echo "Marketplace source: ${repo_root}"
echo "Plugin cache: ${plugin_install_root}"
echo "Updated Codex config: ${config_path}"
echo "Restart Codex to load the plugin marketplace."
