# mcp-hello-go-server

[![ci](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/ci.yml/badge.svg)](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/ci.yml) [![image-scan](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/image-scan.yml/badge.svg)](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/image-scan.yml) [![govulncheck](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/govulncheck.yml/badge.svg)](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/govulncheck.yml) [![publish](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/publish.yml/badge.svg)](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/publish.yml) [![publish-dockerhub](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/publish-dockerhub.yml/badge.svg)](https://github.com/mitchallen/mcp-hello-go-server/actions/workflows/publish-dockerhub.yml)

[![Docker Hub](https://img.shields.io/docker/v/mitchallen/mcp-hello-go-server?sort=semver&logo=docker&label=docker%20hub)](https://hub.docker.com/r/mitchallen/mcp-hello-go-server) [![image size](https://img.shields.io/docker/image-size/mitchallen/mcp-hello-go-server?sort=semver&logo=docker&label=image%20size)](https://hub.docker.com/r/mitchallen/mcp-hello-go-server/tags) [![Docker pulls](https://img.shields.io/docker/pulls/mitchallen/mcp-hello-go-server?logo=docker&label=pulls)](https://hub.docker.com/r/mitchallen/mcp-hello-go-server) [![GHCR](https://img.shields.io/badge/ghcr.io-mitchallen%2Fmcp--hello--go--server-2496ed?logo=github)](https://github.com/mitchallen/mcp-hello-go-server/pkgs/container/mcp-hello-go-server) [![License: MIT](https://img.shields.io/badge/license-MIT-green)](#license)

A minimal [MCP](https://modelcontextprotocol.io) server built with **Go** and the
official [`go-sdk`](https://github.com/modelcontextprotocol/go-sdk) — a good
starting point for a new server or a demo. It exposes just two tools:

- **`server_info`** — a health/status check.
- **`greet`** — a friendly greeting in one of a handful of languages, defaulting
  to English. Ask it to "greet in French" and it replies `Bonjour!`.

Built with **Go**, the **[go-sdk](https://github.com/modelcontextprotocol/go-sdk)**,
and **make**. It is the Go port of the sibling Python
[`mcp-hello-server`](../mcp-hello-server), following the official MCP
[Build a server (Go)](https://modelcontextprotocol.io/docs/develop/build-server#go)
reference. The Docker image is a static binary on a distroless base — about
**17 MB** and **0 known vulnerabilities**.

* * *

## Quick start — demo an MCP server in 2 minutes

New to MCP? This is a tiny, safe server for **seeing how an MCP client discovers
and calls tools**. Every tool is a harmless in-memory lookup, so it's a good
sandbox. All you need is **[Docker](https://docs.docker.com/get-docker/)** and an
MCP client — the steps below use **[Claude Code](https://claude.com/claude-code)**
and the published Docker image (nothing to build or install).

> **Already running the Python or Rust hello server?** The sibling
> [`mcp-hello-server`](../mcp-hello-server) (alias `hello`) and
> [`mcp-hello-rust-server`](../mcp-hello-rust-server) (alias `hello-rust`) expose
> the same `server_info` / `greet` tools, so it's easy to test the wrong one.
> Remove any you don't want registered so your client only talks to `hello-go`:
>
> ```sh
> claude mcp list                # see what's registered
> claude mcp remove hello        # the Python server, if present
> claude mcp remove hello-rust   # the Rust server, if present
> ```
>
> Add `--scope user` / `--scope project` if it was registered at that scope. In
> Claude Desktop, delete the entry from `mcpServers` in
> `claude_desktop_config.json` instead and restart.

**1. Add the server.** Claude Code launches the container per session and talks
to it over stdio:

```sh
claude mcp add hello-go -- docker run -i --rm -e MCP_TRANSPORT=stdio ghcr.io/mitchallen/mcp-hello-go-server:latest
```

**2. Confirm it connected:**

```sh
claude mcp list        # "hello-go" should report ✔ Connected
```

**3. Ask in plain language** — Claude discovers the tools and picks one (the tool
it calls is in parentheses):

- "Is the hello server up? What version is it?" → (`server_info`)
- "Greet me in French." → (`greet` → **Bonjour!**)
- "Say hello in Japanese to Alice." → (`greet` → **こんにちは (Konnichiwa), Alice!**)
- "What languages can you greet in?" → (`server_info`, reads `languages`)

That round trip — the client listing tools, then calling one with arguments and
getting structured JSON back — *is* MCP.

**4. Remove it when you're done:**

```sh
claude mcp remove hello-go
```

> **Prefer HTTP?** Run it as a long-lived server instead:
> ```sh
> docker run --rm -p 8000:8000 ghcr.io/mitchallen/mcp-hello-go-server:latest
> claude mcp add --transport http hello-go http://localhost:8000/mcp
> ```

* * *

## Tools

| Tool                        | Purpose                                                        |
| --------------------------- | ------------------------------------------------------------- |
| `server_info()`             | Health/status: app name, version, uptime, supported languages |
| `greet(language?, name?)`   | Greeting in `language` (default English); optional `name`     |

### `greet`

`greet` takes two optional arguments:

- **`language`** — a language name, an alternate spelling, or an ISO code
  (case-insensitive). Omit it to default to English. Supported: `english`,
  `spanish`, `french`, `german`, `italian`, `portuguese`, `japanese`,
  `hawaiian` (e.g. `french`, `Français`, or `fr` all work).
- **`name`** — optional; personalizes the message (`Bonjour, Alice!`).

It returns `{ language, greeting, message }`:

```jsonc
// greet(language="french")
{ "language": "french", "greeting": "Bonjour", "message": "Bonjour!" }

// greet(language="spanish", name="Alice")
{ "language": "spanish", "greeting": "Hola", "message": "Hola, Alice!" }

// greet()  -> { "language": "english", "greeting": "Hello", "message": "Hello!" }
```

An unknown language returns a tool error listing the supported set.

### Add a language

Add a row to `greetings` in `greetings.go` (and, optionally, an alias / ISO code
to `aliases`). `server_info` reports the supported set automatically.

* * *

## Quick start (from source)

Requires [Go](https://go.dev/dl/) 1.26+.

```sh
make build       # go build -> ./mcp-hello-go-server
make test        # run the test suite
make run         # run the server over stdio
```

`make help` lists every target.

* * *

## Running the server

### stdio (default — for MCP clients that launch the server)

```sh
go run .
# or
make run
```

### Streamable HTTP (for networked clients / containers)

```sh
make run-http            # PORT defaults to 8000
PORT=9000 make run-http
```

The MCP endpoint is served at `/mcp`.

* * *

## Configuration

All configuration is via environment variables:

| Variable        | Default               | Purpose                                    |
| --------------- | --------------------- | ------------------------------------------ |
| `APP_NAME`      | `mcp-hello-go-server` | Name reported by `server_info`             |
| `MCP_TRANSPORT` | `stdio`               | `stdio` or `http`                          |
| `HOST`          | `127.0.0.1`           | Bind address for `http`                    |
| `PORT`          | `8000`                | Bind port for `http`                       |

* * *

## Using with an MCP client — local development (from source)

Point a stdio-based client (e.g. Claude Desktop, Claude Code) at the built
binary. With Claude Code, from the project directory:

```sh
make build
claude mcp add hello-go -- "$PWD/mcp-hello-go-server"
```

Confirm it's connected with `claude mcp list` (or `/mcp` inside a session).

### Example prompts (Claude Code)

Once the server is added, just ask in plain language — Claude picks the right
tool. The tool it invokes is shown in parentheses.

- "Is the hello server up? What version is it?" → (`server_info`)
- "Greet me." → (`greet`, defaults to English → "Hello!")
- "Greet in French." → (`greet` with `language="french"` → "Bonjour!")
- "Say hello in Japanese to Alice." → (`greet` with `language="japanese"`, `name="Alice"`)
- "What languages can you greet in?" → (`server_info`, then read `languages`)

* * *

## Using a published image

The image is published to two registries:

- **GitHub Container Registry:** `ghcr.io/mitchallen/mcp-hello-go-server`
- **Docker Hub:** `mitchallen/mcp-hello-go-server`

### Option A — Docker image, client launches it (stdio)

This is the simplest setup: **there's nothing to build or install** — just the
published image. Strictly speaking you don't even have to pull it first —
`docker run` auto-pulls any image missing from the local cache (standard Docker
behavior, not client-specific) the first time the container launches. But that
first launch then blocks on the download, which can race an MCP client's
connect/startup timeout and make the server look like it failed to connect. So
pull it up front once:

```sh
docker pull ghcr.io/mitchallen/mcp-hello-go-server:latest
```

After that it's cached locally and every session starts instantly from the local
copy.

The client starts a fresh container per session and talks to it over stdio. Use
`-i` (keep stdin open) and force the stdio transport, since the image defaults to
HTTP:

```jsonc
{
  "mcpServers": {
    "hello-go": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "MCP_TRANSPORT=stdio",
               "ghcr.io/mitchallen/mcp-hello-go-server:latest"]
    }
  }
}
```

Claude Code equivalent:

```sh
claude mcp add hello-go -- docker run -i --rm -e MCP_TRANSPORT=stdio ghcr.io/mitchallen/mcp-hello-go-server:latest
```

(Pin a version like `:0.1.0` in place of `:latest` for a reproducible setup.)

### Option B — Long-running container over HTTP

The image serves HTTP by default. Start it once, then point an HTTP-capable
client at it:

```sh
docker run -d --rm -p 8000:8000 --name mcp-hello-go ghcr.io/mitchallen/mcp-hello-go-server:latest
claude mcp add --transport http hello-go http://localhost:8000/mcp
```

For clients that only speak **stdio**, bridge to the HTTP endpoint with
[`mcp-remote`](https://www.npmjs.com/package/mcp-remote):

```jsonc
{
  "mcpServers": {
    "hello-go": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://localhost:8000/mcp"]
    }
  }
}
```

Notes for remote use:

- Prefer **HTTPS** so traffic is encrypted in transit.
- This server ships **no authentication**. If you expose it beyond localhost, put
  it behind a reverse proxy, gateway, or network policy.
- The endpoint path is `/mcp`.

* * *

## Docker

Published multi-platform (`linux/amd64`, `linux/arm64`) images run the server
over **streamable HTTP** by default (`MCP_TRANSPORT=http`, `HOST=0.0.0.0`,
`PORT=8000`) so they're reachable on a published port.

The build compiles a **static** (`CGO_ENABLED=0`) binary and copies it onto a
distroless **[Chainguard/Wolfi](https://images.chainguard.dev) `static` base** —
no shell, no package manager, runs as a non-root user, ~17 MB, and scans **0
known vulnerabilities** with Trivy. Because Go cross-compiles per target
architecture with its own toolchain, the multi-arch build needs **no QEMU
emulation** — the arm64 image is cross-compiled natively on the amd64 runner.
Every build is gated by a Trivy scan (fails on fixable CRITICAL/HIGH); the Go
dependency tree and standard library are separately scanned with `govulncheck`,
and the published `:latest` is re-scanned daily — see [Security
scanning](#security-scanning).

### Pull and run

```sh
docker pull ghcr.io/mitchallen/mcp-hello-go-server:latest
docker run --rm -p 8000:8000 --name mcp-hello-go ghcr.io/mitchallen/mcp-hello-go-server:latest
```

Then connect an HTTP MCP client to `http://localhost:8000/mcp`.

### Test a published release with make

```sh
make docker-test               # up + smoke + down in one shot (exits non-zero on failure)

make docker-up                 # pull + run ghcr.io/mitchallen latest, detached
make docker-smoke              # MCP `initialize` handshake — passes if the server responds
make docker-down               # stop it

make docker-up TAG=0.1.0                         # pin a version
make docker-up REGISTRY=docker.io/mitchallen     # pull from Docker Hub instead
make docker-up HTTP_PORT=9000                    # publish on a different host port
```

### Build locally

```sh
make docker-build        # docker build -t mcp-hello-go-server .
make docker-run          # serves http on localhost:8000
make scan                # Trivy scan of the local image (fixable CRITICAL/HIGH fail)
```

* * *

## Security scanning

Two complementary gates catch vulnerabilities, both reproducible locally:

- **`image-scan`** (`make scan`) — Trivy scans the built container image and
  fails the build on **fixable** CRITICAL/HIGH vulnerabilities. Trivy also reads
  the Go binary's embedded module list, so it flags vulnerable module versions
  compiled in.
- **`govulncheck`** (`make vulncheck`) — a call-graph-aware scan of Go
  dependencies **and the standard library** against the
  [Go vulnerability database](https://pkg.go.dev/vuln). It reports only
  vulnerabilities in code paths actually reachable, and runs with the newest
  **stable** Go in CI.
- **`scan-scheduled`** re-scans the published `:latest` image daily and uploads
  results to the GitHub Security tab, catching CVEs disclosed after build time.
- **Dependabot** opens weekly PRs for Go modules, the Docker base image, and
  GitHub Actions; low-risk updates auto-merge once CI passes.

> **Tip:** `govulncheck` also flags standard-library CVEs tied to your local Go
> toolchain patch. If `make check` reports a `crypto/*` finding, update Go to the
> patch version it names — CI uses the latest `stable` Go, so it stays green.

* * *

## CI / Publish

Workflows live in `.github/workflows/`:

- **`ci`** — on every push/PR to `main`: `gofmt` check, `go vet`, and `go test`.
- **`govulncheck`** / **`image-scan`** / **`scan-scheduled`** — vulnerability
  scanning (see above).
- **`publish`** / **`publish-dockerhub`** — triggered by pushing a `v*` tag.
  Build a multi-platform image (version stamped via `-ldflags`), Trivy-scan it,
  push it to GHCR and Docker Hub, then run `make docker-test` against the
  just-published image. The Docker Hub job needs `DOCKERHUB_USERNAME` /
  `DOCKERHUB_TOKEN` repository secrets.

To cut a release, use the `release` target — it bumps `var version` in
`server.go`, commits, tags, pushes, and creates the GitHub Release from the
`CHANGELOG.md` section, which triggers both publish workflows:

```sh
make release              # patch bump (default)
make release BUMP=minor   # or minor / major
```

The target refuses to run unless the working tree is clean, you're on `main`, and
`CHANGELOG.md` already has a `## [X.Y.Z]` section for the new version.

### Docker Hub secrets (one-time setup)

Pushing to **GHCR** needs no setup — it uses the built-in `GITHUB_TOKEN`. The
**`publish-dockerhub`** job additionally needs two repository secrets and a
pre-created Docker Hub repo:

1. **Create a Docker Hub access token** (not your password) with **Read & Write**
   permissions, at hub.docker.com → Account Settings → Personal access tokens.
2. **Create the Docker Hub repository** `mitchallen/mcp-hello-go-server` (Public).
3. **Add the two GitHub secrets** — `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`:

   ```sh
   gh secret set DOCKERHUB_USERNAME --body "mitchallen"
   gh secret set DOCKERHUB_TOKEN          # prompts for the value — paste the token
   ```

Without these, the GHCR `publish` job still succeeds; only `publish-dockerhub`
fails at the login step.

* * *

## Development

- Source: single `package main`
  - `greetings.go` — greeting data + language resolution (`greet`), unit-tested
  - `server.go` — `newServer()` + tool handlers registered with `mcp.AddTool`
  - `main.go` — the entry point; transport wiring (stdio / HTTP)
- Tests: `server_test.go` drives the tools through an **in-memory client**
  (`mcp.NewInMemoryTransports`, no network/subprocess); `greetings_test.go`
  unit-tests the resolver/builder. Run everything with `make test`, or the full
  CI gate with `make check` (gofmt + vet + test + govulncheck).
- **Dependencies:** `go.mod` / `go.sum` are committed. Run `make tidy`
  (`go mod tidy`) after changing dependencies.

* * *

## License

MIT © Mitch Allen
