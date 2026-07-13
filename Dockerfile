# --- Stage 1: Build ---
# Pin to the build platform and cross-compile with Go's own toolchain (GOARCH),
# so a multi-arch buildx build never pays for QEMU emulation — the arm64 binary
# is cross-compiled natively on the amd64 builder. CGO_ENABLED=0 yields a fully
# static binary that runs on an empty base.
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder
WORKDIR /app

# Download dependencies first as a cached layer (only go.mod/go.sum change → reuse).
COPY go.mod go.sum ./
RUN go mod download

# Build the static binary for the target platform.
COPY *.go ./
ARG TARGETOS TARGETARCH VERSION=0.1.0
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" \
    -o /mcp-hello-go-server .

# --- Stage 2: Production ---
# Distroless Chainguard/Wolfi "static" base — no shell, no package manager, and
# it already runs as the non-root 'nonroot' user (uid 65532). It carries only CA
# certs and tzdata, so a static binary on top scans near-zero vulnerabilities.
FROM cgr.dev/chainguard/static:latest AS prod

# Serve over streamable HTTP by default so the container is reachable on a
# published port; MCP_TRANSPORT=stdio switches to stdio for client-launched use.
ENV MCP_TRANSPORT=http \
    HOST=0.0.0.0 \
    PORT=8000

COPY --from=builder /mcp-hello-go-server /usr/local/bin/mcp-hello-go-server

EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/mcp-hello-go-server"]
