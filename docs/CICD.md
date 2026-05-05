# CI / CD

## Release entry points

- `scripts/release-package.sh` — builds the universal `OpenAra.app`, stages the root/alias npm packages (each bundles the macOS app), and emits `dist/release/npm/*.tgz` plus `dist/release/release-manifest.json`. CI defaults to ad-hoc signing; local debug/dev builds can use the developer's own signing identity.
- `scripts/build-cursor-motion-dmg.sh` — local build for `Cursor Motion.app`, wrapped into `dist/release/cursor-motion/CursorMotion-<version>.dmg`. Supports `native` / `arm64` / `x86_64` / `universal`.
- `.github/workflows/release.yml` — runs on `v*` / semver tag pushes (also manually triggerable). On a tag push it runs the npm release packaging plus the Cursor Motion DMG and uploads the `.dmg` to the matching GitHub Release. OpenAra npm artifacts default to ad-hoc signing; with `OPENARA_CODESIGN_*` secrets configured the workflow imports a `Developer ID Application` certificate and signs the release `.app` with that identity. The Cursor Motion DMG reuses the same certificate; with `APPLE_NOTARY_*` secrets it also notarizes and staples before upload.

## Principles

- All GitHub Actions are pinned to commit SHA; keep them pinned when upgrading.
- Don't add a parallel build path. Extend the existing `scripts/release-package.sh` chain when adding artifacts.
- Keep SBOM / provenance hooks even if the deployment surface changes.

## Default release artifacts

The current release run produces:

- `dist/release/release-manifest.json`
- `dist/release/npm/openara-<version>.tgz`
- `dist/release/npm/openara-mcp-<version>.tgz`
- `dist/release/cursor-motion/CursorMotion-<version>.dmg`
- The GitHub Actions npm release artifact upload
- The tagged `CursorMotion-<version>.dmg` on GitHub Releases

The repo therefore has, as of today, both a reusable npm packaging chain and a tag-driven macOS app DMG delivery chain — neither requires a deployment platform on top.
