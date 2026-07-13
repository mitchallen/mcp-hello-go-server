# mcp-hello-go-server — notes for Claude

A minimal MCP server built with **Go** and the official
[`go-sdk`](https://github.com/modelcontextprotocol/go-sdk) — a good starting
point for a new server or a demo. It exposes two tools: `server_info` (a
health/status check) and `greet` (a friendly greeting in one of a handful of
languages, defaulting to English). Built with **go** and **make**; a multi-stage
Docker build produces a static binary on a distroless Chainguard/Wolfi `static`
base (`cgr.dev/chainguard/static`) for a ~17 MB, near-zero-CVE image. It is the
Go port of the sibling Python [`mcp-hello-server`](../mcp-hello-server),
following the official MCP "Build a server (Go)" reference.

## Layout

Single `package main` (a small binary), split by concern:

- `greetings.go` — greeting data (`greetings`), language resolution (names,
  aliases, ISO codes), and the `greet()` builder. Unit-tested in
  `greetings_test.go`.
- `server.go` — `newServer()` builds the `mcp.Server`, defines the tool
  input/output structs and handlers (`handleServerInfo`, `handleGreet`), and
  registers them with `mcp.AddTool`.
- `main.go` — the entry point; picks the transport from `MCP_TRANSPORT` and wires
  up stdio (`server.Run` + `mcp.StdioTransport`) or streamable HTTP
  (`mcp.NewStreamableHTTPHandler` mounted at `/mcp`).
- `server_test.go` — integration tests connecting a client and server over
  `mcp.NewInMemoryTransports()` (the analog of the Python suite's in-memory
  FastMCP client). No network, no subprocess.

## Conventions

- **Build / deps:** the Go toolchain. `go.mod`/`go.sum` are committed. `make
  build` embeds the version via `-ldflags "-X main.version=..."`.
- **Version:** the source of truth is `var version` in `server.go`; `make
  release` seds that literal. Docker/CI pass the tag as `--build-arg VERSION=` →
  `-ldflags -X main.version`.
- **Running:** `make run` (stdio, the default MCP transport), `make run-http`
  (streamable HTTP on `PORT`, default 8000). The transport is chosen by
  `MCP_TRANSPORT` (`stdio` | `http`); the HTTP endpoint is `/mcp`.
- **Tests / gate:** `make test` (`go test ./...`), `make check` (gofmt check +
  `go vet` + tests + `govulncheck`) — the CI gate.
- **Adding a language:** add a row to `greetings` in `greetings.go` (and,
  optionally, an alias / ISO code to `aliases`). `server_info` reports the set
  automatically.
- **Docker:** the image defaults to HTTP transport (`MCP_TRANSPORT=http`,
  `HOST=0.0.0.0`, `PORT=8000`). The binary is built `CGO_ENABLED=0` (fully
  static) and cross-compiled per `TARGETARCH` with Go's toolchain — so multi-arch
  buildx needs **no QEMU** (unlike an emulated compile). It's copied onto
  `cgr.dev/chainguard/static`, which has no shell / package manager and runs as
  the non-root `nonroot` user (uid 65532). `make scan` should report 0
  CRITICAL/HIGH.
- **Releasing:** `make release` (`BUMP=patch|minor|major`, default patch) bumps
  `var version` in `server.go`, commits, tags `vX.Y.Z`, pushes, and creates the
  matching GitHub Release from the `CHANGELOG.md` section. The tag triggers the
  GHCR + Docker Hub publish workflows. It refuses to run unless the tree is
  clean, you're on `main`, and `CHANGELOG.md` already has the new version's
  section.

## Tools

| Tool                       | Purpose                                                  |
| -------------------------- | -------------------------------------------------------- |
| `server_info()`            | Health/status: app name, version, uptime, languages.     |
| `greet(language?, name?)`  | Greeting in a language (default English); optional name. |

Supported languages: `english`, `spanish`, `french`, `german`, `italian`,
`portuguese`, `japanese`, `hawaiian`. Lookups accept aliases / ISO codes
(`fr`, `Français`, …) case-insensitively.

## Security scanning

Two complementary gates, both in CI and reproducible locally:

- **`image-scan`** (`make scan`) — Trivy scans the built image and fails on
  fixable CRITICAL/HIGH. Trivy reads the Go binary's embedded module list, so it
  also flags vulnerable module versions compiled in.
- **`govulncheck`** (`make vulncheck`) — call-graph-aware scan of Go
  dependencies **and the standard library** against the Go vuln DB. It only
  reports vulnerabilities in code paths actually reachable. Runs with the newest
  **stable** Go in CI so a stdlib CVE fixed in a newer patch doesn't fail the
  build.
- **`scan-scheduled`** re-scans the published `:latest` daily.

## Gotchas

- **Tool handlers return `(*mcp.CallToolResult, Out, error)`.** Return a non-nil
  `Out` and a nil result to get structured content auto-populated. For a
  recoverable tool error (unknown language) return a `*mcp.CallToolResult` with
  `IsError: true` and a `TextContent` message — a *tool-level* error the model
  can see, not a protocol error (don't return a non-nil `error` for that).
- **Optional tool args:** `greetInput` fields use `json:"...,omitempty"` so the
  generated schema treats `language`/`name` as optional; omitted → English.
- **Logs go to stderr** (`log.SetOutput(os.Stderr)`): the stdio transport owns
  stdout for the JSON-RPC stream, so a stray stdout write corrupts the protocol.
- **stdio + closed stdin:** the SDK's stdio server shuts down on stdin EOF, so a
  one-shot `printf ... | server` test exits before replying — hold stdin open
  (e.g. `{ printf ...; sleep 1; } | server`) or use the in-memory client.
- **govulncheck vs local Go:** it also flags **stdlib** CVEs tied to the local
  toolchain patch. If `make check` reports a `crypto/*` finding, update Go to the
  patch it names (CI uses `stable`, so CI stays green regardless).
