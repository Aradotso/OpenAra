# Security policy

## Reporting a vulnerability

Do not open a public issue for suspected security vulnerabilities.

Email security@ara.so with:

- The component affected (CLI, MCP server, permission flow, etc.).
- Reproduction steps or a proof-of-concept.
- The blast radius (local-only, requires a malicious app, etc.).
- Any mitigations you've already identified.

We aim to acknowledge within two business days and patch confirmed issues
within 30 days, or sooner for high-severity reports.

## Scope

OpenAra runs locally on the user's Mac. There is no cloud component, no
authentication boundary, and no remote attack surface in the default setup.
Reports we care about most:

- macOS TCC / Accessibility / Screen Recording bypass paths.
- Privilege escalation through the MCP server's input synthesis.
- Code execution from a malicious MCP client payload.
- Information leakage from the visible cursor overlay or accessibility snapshots.
