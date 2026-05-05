# Contributing to OpenAra

OpenAra is the open-source Computer Use server from Ara. We welcome PRs.

## Before you start

1. Read [`README.md`](./README.md) and [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).
2. Make sure `swift build` and `swift test` pass on a clean checkout.
3. Open an issue describing the change for anything non-trivial.

## What we accept

- Bug fixes, especially around macOS Accessibility / Screen Recording edge cases.
- Performance improvements with reproducible measurements.
- New tools that strictly extend the OpenAI Computer Use surface (the nine canonical tools must remain spec-compliant; extension tools live behind the registry's extension hook).
- Test coverage.
- Documentation in English.

## What we won't merge

- Linux or Windows runtimes — OpenAra is opinionated about macOS.
- Renaming or restructuring the nine MCP tool wire names / argument schemas — they're frozen by OpenAI's Computer Use spec.
- Changes that strip upstream attribution from `LICENSE` or `README.md` (MIT requires the original copyright notice to stay).
- Documentation in any language other than English.

## Pull request checklist

- `swift build` clean (no warnings introduced).
- `swift test` 100% green.
- New behavior covered by a Swift Testing `@Test`.
- Commit message describes the *why*, not just the *what*.

## License

By contributing, you agree your contribution is licensed under MIT alongside the rest of OpenAra.
