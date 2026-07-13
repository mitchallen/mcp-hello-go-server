# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-07-13

### Added

- Initial release: a minimal MCP server built with **Go** and the official
  [`go-sdk`](https://github.com/modelcontextprotocol/go-sdk), exposing two tools —
  - `server_info()` — a health/status check reporting the app name, version,
    uptime, supported greeting languages, and default language.
  - `greet(language?, name?)` — a friendly greeting in one of a handful of
    languages (english, spanish, french, german, italian, portuguese, japanese,
    hawaiian), defaulting to English. Accepts a language name, alternate
    spelling, or ISO code (case-insensitive), and an optional `name` to
    personalize the message.
- Serves over **stdio** (default) or **streamable HTTP** (`MCP_TRANSPORT=http`),
  selected at runtime; the MCP endpoint is `/mcp`.
- A test suite driven through an in-memory client (`mcp.NewInMemoryTransports`)
  in `server_test.go`, plus unit tests for the greeting resolver/builder in
  `greetings_test.go`.
- Multi-stage **Docker** build producing a static (`CGO_ENABLED=0`) binary on a
  distroless Chainguard/Wolfi `static` base — a ~17 MB image that runs as a
  non-root user and scans **0 known vulnerabilities** with Trivy. The build
  cross-compiles per target arch with Go's own toolchain, so multi-arch builds
  need no QEMU emulation.
- **CI**: a `ci` workflow (gofmt + vet + tests), a `govulncheck` workflow
  scanning dependencies and the standard library against the Go vulnerability
  database, an `image-scan` workflow that fails on fixable CRITICAL/HIGH image
  vulnerabilities, a daily `scan-scheduled` re-scan of the published `:latest`
  image, and GHCR + Docker Hub `publish` workflows gated behind a pre-push Trivy
  scan.
- A Dependabot config opening weekly update PRs for Go modules, the Docker base
  image, and GitHub Actions, with low-risk updates auto-merged once CI passes.

[unreleased]: https://github.com/mitchallen/mcp-hello-go-server/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mitchallen/mcp-hello-go-server/releases/tag/v0.1.0
