#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${repo_root}"

swift build
OPENARA_VISUAL_CURSOR=0 ".build/debug/OpenAraSmokeSuite"
".build/debug/OpenAraSmokeSuite" --cursor-idle-only
