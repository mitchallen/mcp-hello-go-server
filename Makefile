# Makefile with help command

IMAGE ?= mcp-hello-go-server
BIN   ?= mcp-hello-go-server

# Version bump level for `make release`: patch (default), minor, or major.
BUMP ?= patch

# Version literal lives in server.go (var version = "X.Y.Z"); read it for builds.
VERSION := $(shell sed -n 's/^var version = "\([0-9.]*\)".*/\1/p' server.go)

# Published image coordinates for pulling/running release images locally.
REGISTRY ?= ghcr.io/mitchallen
TAG ?= latest
PUBLISHED_IMAGE ?= $(REGISTRY)/mcp-hello-go-server
CONTAINER ?= mcp-hello-go
HTTP_PORT ?= 8000

.PHONY: all
all: help

.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make build        - Build the binary (embeds version via -ldflags)"
	@echo "  make run          - Run the MCP server over stdio"
	@echo "  make run-http     - Run the MCP server over streamable HTTP (PORT, default 8000)"
	@echo "  make test         - Run the test suite (go test)"
	@echo "  make fmt          - Format the code (gofmt -w)"
	@echo "  make vet          - Run go vet"
	@echo "  make vulncheck    - Scan Go dependencies with govulncheck"
	@echo "  make check        - fmt check + vet + test + vulncheck (the CI gate)"
	@echo "  make tidy         - go mod tidy"
	@echo "  make release      - Bump version (BUMP=patch|minor|major), commit, tag, and push"
	@echo "  make docker-build - Build the Docker image locally"
	@echo "  make docker-run   - Run the locally-built image over HTTP on port 8000"
	@echo "  make docker-pull  - Pull the published image (REGISTRY, TAG)"
	@echo "  make docker-up    - Pull and run the published image detached (HTTP_PORT, TAG)"
	@echo "  make docker-smoke - Smoke-test the running container's MCP endpoint (HTTP_PORT)"
	@echo "  make docker-test  - Up + smoke + down in one shot (CI gate for a published image)"
	@echo "  make docker-logs  - Follow logs of the running test container"
	@echo "  make docker-down  - Stop the running test container"
	@echo "  make scan         - Scan the Docker image for vulnerabilities (Trivy)"
	@echo "  make docker-rm    - Remove the Docker image"
	@echo "  make docker-prune - Prune unused Docker data"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make help         - Display this help message"

.PHONY: build
build:
	@echo "Building $(BIN) v$(VERSION)..."
	go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o $(BIN) .

.PHONY: run
run:
	MCP_TRANSPORT=stdio go run .

.PHONY: run-http
run-http:
	MCP_TRANSPORT=http HOST=0.0.0.0 PORT=$${PORT:-8000} go run .

.PHONY: test
test:
	@echo "Running tests..."
	go test ./...

.PHONY: fmt
fmt:
	gofmt -w .

.PHONY: vet
vet:
	go vet ./...

# Scan Go dependencies against the Go vulnerability database.
.PHONY: vulncheck
vulncheck:
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...

# The full local CI gate: formatting, vet, tests, and dependency vuln scan.
.PHONY: check
check:
	@test -z "$$(gofmt -l .)" || { echo "gofmt needed on:"; gofmt -l .; exit 1; }
	go vet ./...
	go test ./...
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...

.PHONY: tidy
tidy:
	go mod tidy

# Bump the version literal in server.go, commit, tag, and push. The pushed v*
# tag triggers the publish workflows (GHCR + Docker Hub). Override with
# BUMP=minor or BUMP=major.
.PHONY: release
release:
	@test -z "$$(git status --porcelain)" || { echo "Working tree is not clean; commit or stash first."; exit 1; }
	@branch=$$(git rev-parse --abbrev-ref HEAD); \
	test "$$branch" = "main" || { echo "Refusing to release from '$$branch'; switch to main."; exit 1; }
	@cur=$(VERSION); \
	major=$$(echo $$cur | cut -d. -f1); minor=$$(echo $$cur | cut -d. -f2); patch=$$(echo $$cur | cut -d. -f3); \
	case "$(BUMP)" in \
	  major) major=$$((major+1)); minor=0; patch=0 ;; \
	  minor) minor=$$((minor+1)); patch=0 ;; \
	  patch) patch=$$((patch+1)) ;; \
	  *) echo "BUMP must be patch, minor, or major"; exit 1 ;; \
	esac; \
	next=$$major.$$minor.$$patch; \
	grep -qE "^## \[$$next\]" CHANGELOG.md || { echo "CHANGELOG.md has no entry for v$$next — add a '## [$$next] - YYYY-MM-DD' section (Keep a Changelog format, top of the file) before releasing."; exit 1; }; \
	echo "Bumping version $$cur -> $$next..."; \
	sed -i.bak "s/^var version = \"[0-9.]*\"/var version = \"$$next\"/" server.go && rm -f server.go.bak; \
	echo "Releasing v$$next..."; \
	git add server.go; \
	git commit -m "Release v$$next"; \
	git tag "v$$next"; \
	git push origin main; \
	git push origin "v$$next"; \
	echo "Creating GitHub release v$$next..."; \
	notes=$$(awk -v v="$$next" '$$0 ~ "^## \\[" v "\\]" {flag=1; next} flag && /^## \[/ {exit} flag {print}' CHANGELOG.md); \
	printf '%s\n' "$$notes" | gh release create "v$$next" --title "v$$next" --notes-file - ; \
	echo "Pushed v$$next and created its GitHub release — the publish workflows will build and push the images."

.PHONY: docker-build
docker-build:
	@echo "Building Docker image locally..."
	docker build --build-arg VERSION=$(VERSION) -t $(IMAGE) .

.PHONY: docker-run
docker-run:
	docker run --rm -p 8000:8000 --name $(IMAGE) $(IMAGE)

.PHONY: docker-pull
docker-pull:
	@echo "Pulling $(PUBLISHED_IMAGE):$(TAG)..."
	docker pull $(PUBLISHED_IMAGE):$(TAG)

.PHONY: docker-up
docker-up: docker-pull
	-docker rm -f $(CONTAINER) 2>/dev/null || true
	docker run -d --rm -p $(HTTP_PORT):8000 --name $(CONTAINER) $(PUBLISHED_IMAGE):$(TAG)
	@echo "Running $(PUBLISHED_IMAGE):$(TAG) as '$(CONTAINER)'."
	@echo "Connect an HTTP MCP client to http://localhost:$(HTTP_PORT)/mcp"

.PHONY: docker-smoke
docker-smoke:
	@docker ps --filter "name=^/$(CONTAINER)$$" --filter "status=running" --format '{{.Names}}' \
	  | grep -q "^$(CONTAINER)$$" \
	  || { echo "FAIL: container '$(CONTAINER)' is not running. Start it with 'make docker-up'."; exit 1; }
	@echo "Smoke-testing MCP endpoint at http://localhost:$(HTTP_PORT)/mcp ..."
	@curl -fsS -L --max-time 10 \
	  -X POST http://localhost:$(HTTP_PORT)/mcp \
	  -H "Content-Type: application/json" \
	  -H "Accept: application/json, text/event-stream" \
	  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"make-smoke","version":"0"}}}' \
	  | grep -q '"name":"mcp-hello-go-server"' \
	  && echo "PASS: server responded to MCP initialize" \
	  || { echo "FAIL: no valid MCP initialize response on port $(HTTP_PORT). Is 'make docker-up' running?"; exit 1; }

.PHONY: docker-logs
docker-logs:
	docker logs -f $(CONTAINER)

.PHONY: docker-down
docker-down:
	@echo "Stopping $(CONTAINER)..."
	-docker stop $(CONTAINER)

.PHONY: docker-test
docker-test:
	@$(MAKE) --no-print-directory docker-up
	@printf "Waiting for MCP endpoint on port $(HTTP_PORT)"; \
	for i in $$(seq 1 30); do \
	  if curl -sS -o /dev/null --max-time 2 http://localhost:$(HTTP_PORT)/mcp 2>/dev/null; then break; fi; \
	  printf "."; sleep 1; \
	done; echo
	@$(MAKE) --no-print-directory docker-smoke; status=$$?; \
	  $(MAKE) --no-print-directory docker-down; \
	  exit $$status

.PHONY: scan
scan:
	@echo "Scanning $(IMAGE) for vulnerabilities (fixable CRITICAL/HIGH fail)..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy \
		image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 $(IMAGE) \
		|| { echo "Vulnerabilities found (or image not built — run 'make docker-build')."; exit 1; }

.PHONY: docker-rm
docker-rm:
	@echo "Removing Docker image..."
	-docker rmi $(IMAGE)

.PHONY: docker-prune
docker-prune:
	@echo "Pruning unused Docker data..."
	docker system prune -f

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(BIN)
	go clean
