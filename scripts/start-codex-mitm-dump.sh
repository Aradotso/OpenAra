#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/start-codex-mitm-dump.sh [session-name]

Description:
  Starts mitmdump in the background and writes capture samples to
  artifacts/codex-dumps/<session-name>/. When session-name is omitted, a
  timestamped directory is generated automatically.

Optional environment variables:
  MITM_LISTEN_HOST      Listen address. Default: 127.0.0.1
  MITM_LISTEN_PORT      Listen port. Default: 8082
  MITM_CA_CERT          mitm CA cert path. Default: $HOME/.mitmproxy/mitmproxy-ca-cert.pem
  CODEX_DUMP_BASE_DIR   Capture output root. Default: <repo>/artifacts/codex-dumps
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
listen_host="${MITM_LISTEN_HOST:-127.0.0.1}"
listen_port="${MITM_LISTEN_PORT:-8082}"
ca_cert="${MITM_CA_CERT:-${HOME}/.mitmproxy/mitmproxy-ca-cert.pem}"
dump_base_dir="${CODEX_DUMP_BASE_DIR:-${repo_root}/artifacts/codex-dumps}"
addon_script="${repo_root}/scripts/codex_dump.py"
timestamp="$(date +%Y%m%d-%H%M%S)"
session_name="${1:-${timestamp}-codex-capture}"
session_dir="${dump_base_dir}/${session_name}"
log_path="${session_dir}/mitmdump.log"
pid_path="${session_dir}/mitmdump.pid"
env_path="${session_dir}/codex-proxy.env"

if ! command -v mitmdump >/dev/null 2>&1; then
  echo "mitmdump not found. Please install mitmproxy first." >&2
  exit 1
fi

if [[ ! -f "${addon_script}" ]]; then
  echo "Missing capture addon: ${addon_script}" >&2
  exit 1
fi

if [[ ! -f "${ca_cert}" ]]; then
  echo "mitm CA cert not found: ${ca_cert}" >&2
  exit 1
fi

if lsof -nP -iTCP:"${listen_port}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port ${listen_port} is already in use. Adjust MITM_LISTEN_PORT." >&2
  exit 1
fi

if [[ -e "${session_dir}" ]]; then
  if find "${session_dir}" -mindepth 1 -maxdepth 1 | read -r _; then
    echo "Session directory already exists and is not empty: ${session_dir}" >&2
    exit 1
  fi
else
  mkdir -p "${session_dir}"
fi

cat >"${env_path}" <<EOF
export HTTPS_PROXY="http://${listen_host}:${listen_port}"
export NO_PROXY="127.0.0.1,localhost"
export SSL_CERT_FILE="${ca_cert}"
EOF

launcher=(nohup)
if command -v setsid >/dev/null 2>&1; then
  launcher+=(setsid)
fi
launcher+=(mitmdump)

"${launcher[@]}" \
  --listen-host "${listen_host}" \
  --listen-port "${listen_port}" \
  -s "${addon_script}" \
  --set codex_dump_dir="${session_dir}" \
  </dev/null >"${log_path}" 2>&1 &

pid=$!
echo "${pid}" >"${pid_path}"

for _ in $(seq 1 20); do
  if ! kill -0 "${pid}" >/dev/null 2>&1; then
    break
  fi
  if lsof -nP -iTCP:"${listen_port}" -sTCP:LISTEN >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

if ! kill -0 "${pid}" >/dev/null 2>&1; then
  echo "mitmdump failed to start. Recent log:" >&2
  if [[ -f "${log_path}" ]]; then
    tail -n 40 "${log_path}" >&2
  fi
  exit 1
fi

if ! lsof -nP -iTCP:"${listen_port}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "mitmdump process started but port ${listen_port} is not listening yet." >&2
  if [[ -f "${log_path}" ]]; then
    tail -n 40 "${log_path}" >&2
  fi
  exit 1
fi

cat <<EOF
mitmdump started in the background.

session_dir: ${session_dir}
pid: ${pid}
log: ${log_path}
env: ${env_path}

To route Codex through the proxy:

  source "${env_path}"
  codex exec --skip-git-repo-check -C /tmp 'reply with one word: ok'

To stop capture:

  kill "${pid}"
EOF
