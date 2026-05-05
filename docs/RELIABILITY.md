# Reliability & ops

## Minimum verification line

- Build: `swift build`
- Unit tests: `swift test`
- End-to-end smoke: `./scripts/run-tool-smoke-tests.sh`
- Local diagnostics:
  - `.build/debug/OpenAra doctor`
  - `.build/debug/OpenAra snapshot <app>`

## Known critical dependencies

- The host must have `Accessibility` and `Screen Recording` permission granted.
- The smoke suite depends on a local GUI session — don't treat it as headless.
- `get_app_state` quality depends on the target app's AX tree and screenshot fidelity. Complex apps will show variance.

## Triage order

1. Run `.build/debug/OpenAra doctor` first. If permissions are missing it opens the onboarding window directly; if everything is granted it just prints the status and exits.
2. `.build/debug/OpenAra list-apps` to confirm the target app is discovered at all.
3. `.build/debug/OpenAra snapshot <app>` to separate a transport issue from a snapshot / action issue.
4. To verify the repo baseline, run the fixture + smoke first — don't open the investigation on a complex third-party app.

## Areas to harden

- Structured logging via `OpenAraLogger` with per-tool categories and a failure-class taxonomy.
- More explicit timeouts and fallbacks around screenshot capture and AX traversal.
- A regression sample of real-world apps in addition to the fixture.

CI/CD structure and release automation defaults live in [`docs/CICD.md`](./CICD.md).
